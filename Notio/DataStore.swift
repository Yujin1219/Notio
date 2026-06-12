//
//  DataStore.swift
//  Notio
//
//  SwiftData 컨테이너를 관리하고, UIKit 화면에서 쉽게 조회/생성/삭제하도록 감싼다.
//  (SwiftUI의 @Query 자동 갱신이 없으므로 화면에서 직접 호출 후 reload 한다.)
//

import Foundation
import SwiftData

final class DataStore {

    static let shared = DataStore()

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private init() {
        do {
            container = try ModelContainer(for: User.self, Note.self)
        } catch {
            fatalError("SwiftData ModelContainer 생성 실패: \(error)")
        }
        seedIfNeeded()
    }

    // MARK: - Users

    /// 이메일로 유저를 찾는다.
    func user(email: String) -> User? {
        let normalized = email.lowercased()
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.email == normalized }
        )
        return (try? context.fetch(descriptor))?.first
    }

    func emailExists(_ email: String) -> Bool {
        user(email: email) != nil
    }

    /// 회원가입. 이메일 중복이면 nil.
    @discardableResult
    func createUser(nickname: String, email: String, password: String) -> User? {
        let normalized = email.lowercased()
        guard !emailExists(normalized) else { return nil }
        let user = User(nickname: nickname, email: normalized,
                        passwordHash: SessionManager.hash(password))
        context.insert(user)
        save()
        return user
    }

    /// 로컬 로그인. 이메일+비밀번호가 맞으면 유저 반환.
    func authenticate(email: String, password: String) -> User? {
        guard let user = user(email: email) else { return nil }
        return user.passwordHash == SessionManager.hash(password) ? user : nil
    }

    // MARK: - Notes

    /// 현재 로그인한 유저의 노트를 최신순으로 가져온다.
    func fetchNotes() -> [Note] {
        let owner = SessionManager.currentEmail ?? ""
        let descriptor = FetchDescriptor<Note>(
            predicate: #Predicate { $0.ownerEmail == owner },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    @discardableResult
    func addNote(title: String,
                 keywords: String,
                 status: NoteStatus = .inProgress,
                 progress: Double = 0.0,
                 category: NoteCategory = .major,
                 contentJSON: String? = nil,
                 sourceText: String? = nil) -> Note {
        let owner = SessionManager.currentEmail ?? ""
        let note = Note(title: title, keywords: keywords,
                        status: status, progress: progress,
                        category: category, ownerEmail: owner, contentJSON: contentJSON)
        note.sourceText = sourceText
        context.insert(note)
        save()
        return note
    }

    func delete(_ note: Note) {
        context.delete(note)
        save()
    }

    /// 완료된 퀴즈 응시 기록을 노트에 추가한다. (최신순으로 맨 앞에 삽입)
    /// 추가 후 학습률·상태를 다시 계산한다.
    func addQuizAttempt(_ attempt: QuizAttempt, to note: Note) {
        var attempts = note.quizAttempts
        attempts.insert(attempt, at: 0)
        if let data = try? JSONEncoder().encode(attempts),
           let json = String(data: data, encoding: .utf8) {
            note.attemptsJSON = json
        }
        refreshProgress(for: note, attempts: attempts)
        save()
    }

    /// 퀴즈 최고 정답률을 학습률로, 80% 이상이면 완료 상태로 갱신한다.
    private func refreshProgress(for note: Note, attempts: [QuizAttempt]) {
        let best = attempts.map(\.percent).max() ?? 0
        note.progress = Double(best) / 100.0
        note.status = best >= 80 ? .completed : .inProgress
    }

    func save() {
        do {
            try context.save()
        } catch {
            print("⚠️ SwiftData 저장 실패: \(error)")
        }
    }

    // MARK: - 학습 스트릭

    struct StreakStats {
        let streak: Int
        let activeWeekdays: Set<Int>   // 이번 주 활동 요일 (0=월 ~ 6=일)
        let weekNoteCount: Int
        let weekQuizCount: Int
    }

    /// 현재 유저의 노트 생성·퀴즈 응시 기록으로 학습 스트릭을 계산한다.
    func streakStats() -> StreakStats {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let notes = fetchNotes()

        // 활동이 있었던 날(자정 기준) 집합
        var activeDayStarts = Set<Date>()
        for note in notes {
            activeDayStarts.insert(cal.startOfDay(for: note.createdAt))
            for attempt in note.quizAttempts {
                activeDayStarts.insert(cal.startOfDay(for: attempt.date))
            }
        }

        // 연속 일수: 오늘(없으면 어제)부터 거슬러 올라가며 카운트
        var streak = 0
        var cursor = activeDayStarts.contains(today)
            ? today
            : cal.date(byAdding: .day, value: -1, to: today)!
        while activeDayStarts.contains(cursor) {
            streak += 1
            cursor = cal.date(byAdding: .day, value: -1, to: cursor)!
        }

        // 이번 주 월요일
        let weekday = cal.component(.weekday, from: today)   // 1=일 ~ 7=토
        let daysFromMonday = (weekday + 5) % 7
        let monday = cal.startOfDay(for: cal.date(byAdding: .day, value: -daysFromMonday, to: today)!)

        var activeWeekdays = Set<Int>()
        for i in 0..<7 {
            let day = cal.startOfDay(for: cal.date(byAdding: .day, value: i, to: monday)!)
            if activeDayStarts.contains(day) { activeWeekdays.insert(i) }
        }

        let weekNoteCount = notes.filter { $0.createdAt >= monday }.count
        var weekQuizCount = 0
        for note in notes {
            for attempt in note.quizAttempts where attempt.date >= monday {
                weekQuizCount += attempt.total
            }
        }

        return StreakStats(streak: streak, activeWeekdays: activeWeekdays,
                           weekNoteCount: weekNoteCount, weekQuizCount: weekQuizCount)
    }

    // MARK: - Seed

    /// 첫 실행 시 데모 계정과 그 계정의 샘플 노트를 한 번 넣어준다.
    /// (로그인 화면에 미리 채워진 study@notio.io 계정. 비밀번호: password)
    private let demoEmail = "study@notio.io"

    private func seedIfNeeded() {
        let userCount = (try? context.fetchCount(FetchDescriptor<User>())) ?? 0
        guard userCount == 0 else { return }

        let demo = User(nickname: "유진", email: demoEmail,
                        passwordHash: SessionManager.hash("password"))
        context.insert(demo)

        let now = Date()
        func daysAgo(_ d: Int) -> Date {
            Calendar.current.date(byAdding: .day, value: -d, to: now) ?? now
        }

        // 운영체제 노트 — 요약·문제·응시 기록까지 채운 데모
        let os = Note(title: "운영체제론 3강", keywords: "CPU 스케줄링, 세마포어, 교착 상태",
                      status: .completed, progress: 1.0, category: .major,
                      ownerEmail: demoEmail, contentJSON: encode(osContent()),
                      createdAt: daysAgo(3))
        os.attemptsJSON = encode(osAttempts(now: now))
        context.insert(os)

        // 데이터베이스 노트 — 진행 중(오답 존재) 데모
        let db = Note(title: "데이터베이스 2강", keywords: "정규화, 함수 종속, 기본키",
                      status: .inProgress, progress: 0.75, category: .major,
                      ownerEmail: demoEmail, contentJSON: encode(dbContent()),
                      createdAt: daysAgo(2))
        db.attemptsJSON = encode(dbAttempts(now: now))
        context.insert(db)

        // 네트워크 노트 — 퀴즈 기록 5회 + 오답 다수
        let net = Note(title: "네트워크 개론 1강", keywords: "OSI 7계층, TCP/IP, DNS",
                       status: .completed, progress: 0.88, category: .liberal,
                       ownerEmail: demoEmail, contentJSON: encode(netContent()),
                       createdAt: daysAgo(4))
        net.attemptsJSON = encode(netAttempts(now: now))
        context.insert(net)

        // 콘텐츠 없는 일반 노트
        context.insert(Note(title: "알고리즘 5강", keywords: "동적 프로그래밍, 분할정복",
                            status: .inProgress, progress: 0.3, category: .major,
                            ownerEmail: demoEmail, createdAt: daysAgo(1)))
        save()
    }

    // MARK: - Seed 빌더

    private func encode<T: Encodable>(_ value: T) -> String? {
        (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) }
    }

    private func defSec(_ heading: String, _ text: String, _ bolded: [String] = []) -> GeneratedSection {
        GeneratedSection(heading: heading, type: "definition", text: text, bolded: bolded,
                         items: nil, columns: nil, rows: nil)
    }
    private func listSec(_ heading: String, _ items: [String]) -> GeneratedSection {
        GeneratedSection(heading: heading, type: "list", text: nil, bolded: nil,
                         items: items, columns: nil, rows: nil)
    }
    private func tableSec(_ heading: String, _ columns: [String], _ rows: [[String]]) -> GeneratedSection {
        GeneratedSection(heading: heading, type: "table", text: nil, bolded: nil,
                         items: nil, columns: columns, rows: rows)
    }
    private func mc(_ q: String, _ opts: [String], _ correct: Int, _ exp: String) -> GeneratedQuiz {
        GeneratedQuiz(type: "multiple", question: q, options: opts, correctIndex: correct,
                      answer: opts[correct], explanation: exp)
    }
    private func sa(_ q: String, _ answer: String, _ exp: String) -> GeneratedQuiz {
        GeneratedQuiz(type: "short", question: q, options: nil, correctIndex: nil,
                      answer: answer, explanation: exp)
    }
    private func pickMC(_ q: String, _ opts: [String], picked: Int, correct: Int) -> AttemptAnswer {
        AttemptAnswer(question: q, options: opts, selectedIndex: picked, correctIndex: correct)
    }
    private func pickSA(_ q: String, typed: String, correct: String, ok: Bool) -> AttemptAnswer {
        AttemptAnswer(question: q, options: [], selectedIndex: -1, correctIndex: -1,
                      isShort: true, typedAnswer: typed, correctText: correct, correctFlag: ok)
    }

    // MARK: 운영체제 데모 콘텐츠

    private func osContent() -> GeneratedContent {
        GeneratedContent(
            title: "운영체제론 3강",
            summaries: [
                GeneratedSummary(
                    title: "CPU 스케줄링",
                    detail: "준비 큐의 여러 프로세스 중 어디에 CPU를 줄지 결정하는 핵심 OS 기능이에요.",
                    sections: [
                        defSec("정의", "CPU 스케줄링은 준비 큐에 있는 프로세스 중 어떤 프로세스에게 CPU를 할당할지 결정하는 메커니즘이에요. 좋은 스케줄링은 CPU 활용률을 높이고 응답 시간을 줄여요.",
                               ["어떤 프로세스에게 CPU를 할당할지"]),
                        listSec("대표 알고리즘", ["FCFS — 도착한 순서대로 처리", "SJF — 짧은 작업 우선, 평균 대기 시간 최소",
                                              "라운드 로빈 — 시간 할당량으로 공정하게 분배", "우선순위 — 우선순위가 높은 작업 먼저"]),
                        tableSec("알고리즘 비교", ["알고리즘", "대기 시간", "방식"],
                                 [["FCFS", "높음", "비선점"], ["SJF", "낮음", "둘 다"], ["RR", "중간", "선점"]])
                    ]),
                GeneratedSummary(
                    title: "동기화와 임계 구역",
                    detail: "여러 프로세스가 공유 자원에 동시 접근할 때 생기는 문제를 막는 방법이에요.",
                    sections: [
                        defSec("정의", "임계 구역은 공유 자원에 접근하는 코드 영역이에요. 한 번에 하나의 프로세스만 들어가도록 상호 배제를 보장해야 해요.",
                               ["한 번에 하나의 프로세스만"]),
                        listSec("핵심 개념", ["경쟁 상태 — 실행 순서에 따라 결과가 달라지는 문제",
                                          "상호 배제 — 동시에 하나만 진입", "세마포어 — P/V 연산으로 접근 제어"])
                    ]),
                GeneratedSummary(
                    title: "교착 상태",
                    detail: "프로세스들이 서로의 자원을 기다리며 무한히 멈추는 상태예요.",
                    sections: [
                        listSec("발생 4조건", ["상호 배제", "점유와 대기", "비선점", "환형 대기"])
                    ])
            ],
            keywords: [
                GeneratedKeyword(title: "CPU 스케줄링", description: "프로세스에 CPU를 배분하는 기능", related: ["FCFS", "SJF", "RR"]),
                GeneratedKeyword(title: "세마포어", description: "P/V 연산으로 임계 구역 접근을 제어하는 도구", related: ["임계 구역", "상호 배제"]),
                GeneratedKeyword(title: "경쟁 상태", description: "실행 순서에 따라 결과가 달라지는 동기화 문제", related: ["동기화", "임계 구역"]),
                GeneratedKeyword(title: "교착 상태", description: "서로 자원을 기다리며 멈추는 상태", related: ["점유와 대기", "환형 대기"])
            ],
            quizzes: osQuizzes())
    }

    private func osQuizzes() -> [GeneratedQuiz] {
        [
            mc("CPU 스케줄링 알고리즘 중 평균 대기 시간이 가장 짧은 것은?",
               ["FCFS (First Come First Served)", "SJF (Shortest Job First)", "라운드 로빈 (Round Robin)", "우선순위 스케줄링"], 1,
               "짧은 작업을 먼저 실행해 평균 대기 시간이 가장 짧아요. 단, 긴 작업이 계속 밀리는 기아(starvation) 문제가 생길 수 있어요."),
            mc("선점형(Preemptive) 스케줄링의 특징으로 옳은 것은?",
               ["도착한 순서대로만 처리한다", "실행 중인 프로세스를 강제로 중단시킬 수 있다", "한 번 실행하면 종료까지 CPU를 점유한다", "우선순위 개념이 없다"], 1,
               "선점형은 우선순위가 높은 작업이 도착하면 실행 중인 작업을 중단하고 CPU를 전환해요."),
            sa("여러 프로세스가 공유 자원에 동시 접근해 실행 순서에 따라 결과가 달라지는 현상을 무엇이라 하나요?",
               "경쟁 상태", "경쟁 상태(Race Condition)는 임계 구역에 대한 동기화로 해결해요."),
            mc("다음 중 교착 상태(Deadlock)의 발생 조건이 아닌 것은?",
               ["상호 배제", "점유와 대기", "비선점", "선점 가능"], 3,
               "교착 상태는 상호 배제·점유와 대기·비선점·환형 대기 4가지가 모두 성립할 때 발생해요. '선점 가능'은 조건이 아니에요."),
            sa("임계 구역에 한 번에 하나의 프로세스만 들어가도록 보장하는 대표적인 동기화 도구는?",
               "세마포어", "세마포어(Semaphore)는 P/V 연산으로 임계 구역 접근을 제어해요.")
        ]
    }

    private func osAttempts(now: Date) -> [QuizAttempt] {
        let cal = Calendar.current
        let q = osQuizzes()
        func opts(_ i: Int) -> [String] { q[i].options ?? [] }
        // 오늘 — 만점
        let today = QuizAttempt(date: now, durationSeconds: 138, answers: [
            pickMC(q[0].question, opts(0), picked: 1, correct: 1),
            pickMC(q[1].question, opts(1), picked: 1, correct: 1),
            pickSA(q[2].question, typed: "경쟁 상태", correct: "경쟁 상태", ok: true),
            pickMC(q[3].question, opts(3), picked: 3, correct: 3),
            pickSA(q[4].question, typed: "세마포어", correct: "세마포어", ok: true)
        ])
        // 이틀 전 — 교착 상태 문제 1개 오답
        let past = QuizAttempt(date: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                               durationSeconds: 182, answers: [
            pickMC(q[0].question, opts(0), picked: 1, correct: 1),
            pickMC(q[1].question, opts(1), picked: 1, correct: 1),
            pickSA(q[2].question, typed: "경쟁상태", correct: "경쟁 상태", ok: true),
            pickMC(q[3].question, opts(3), picked: 2, correct: 3),
            pickSA(q[4].question, typed: "세마포어", correct: "세마포어", ok: true)
        ])
        return [today, past]   // 최신순
    }

    // MARK: 데이터베이스 데모 콘텐츠

    private func dbContent() -> GeneratedContent {
        GeneratedContent(
            title: "데이터베이스 2강",
            summaries: [
                GeneratedSummary(
                    title: "정규화",
                    detail: "데이터 중복과 이상 현상을 줄이기 위해 테이블을 분해하는 과정이에요.",
                    sections: [
                        defSec("정의", "정규화는 함수 종속성을 바탕으로 테이블을 더 작은 테이블로 나누어 중복과 갱신·삽입·삭제 이상을 줄이는 과정이에요.",
                               ["중복과 갱신·삽입·삭제 이상을 줄이는"]),
                        tableSec("정규형 단계", ["정규형", "제거 대상"],
                                 [["1NF", "원자값이 아닌 속성"], ["2NF", "부분 함수 종속"], ["3NF", "이행 함수 종속"]])
                    ]),
                GeneratedSummary(
                    title: "키(Key)",
                    detail: "행을 식별하고 테이블을 연결하는 속성이에요.",
                    sections: [
                        listSec("종류", ["기본키 — 행을 유일하게 식별, NULL 불가",
                                       "외래키 — 다른 테이블의 기본키를 참조", "후보키 — 기본키가 될 수 있는 속성"])
                    ])
            ],
            keywords: [
                GeneratedKeyword(title: "정규화", description: "중복·이상을 줄이려 테이블을 분해하는 과정", related: ["1NF", "2NF", "3NF"]),
                GeneratedKeyword(title: "함수 종속", description: "한 속성이 다른 속성을 결정하는 관계", related: ["부분 종속", "이행 종속"]),
                GeneratedKeyword(title: "기본키", description: "행을 유일하게 식별하는 키", related: ["후보키", "외래키"]),
                GeneratedKeyword(title: "이상 현상", description: "중복으로 인한 갱신·삽입·삭제 문제", related: ["정규화"])
            ],
            quizzes: dbQuizzes())
    }

    private func dbQuizzes() -> [GeneratedQuiz] {
        [
            mc("제3정규형(3NF)을 만족하기 위해 제거해야 하는 것은?",
               ["부분 함수 종속", "이행 함수 종속", "다치 종속", "원자값이 아닌 속성"], 1,
               "3NF는 이행 함수 종속을 제거한 정규형이에요."),
            mc("기본키(Primary Key)의 특징으로 옳지 않은 것은?",
               ["행을 유일하게 식별한다", "NULL 값을 가질 수 없다", "중복 값을 가질 수 있다", "테이블당 하나만 지정한다"], 2,
               "기본키는 중복 값을 가질 수 없어요. 유일성과 최소성을 만족해야 해요."),
            sa("모든 속성이 더 이상 분해되지 않는 원자값만 갖도록 한 정규형은 무엇인가요?",
               "제1정규형", "제1정규형(1NF)은 모든 속성이 원자값만 갖도록 해요."),
            mc("제2정규형(2NF)에서 제거하는 종속은?",
               ["이행 함수 종속", "부분 함수 종속", "결정자 종속", "다치 종속"], 1,
               "2NF는 기본키의 일부에만 종속되는 부분 함수 종속을 제거해요.")
        ]
    }

    private func dbAttempts(now: Date) -> [QuizAttempt] {
        let cal = Calendar.current
        let q = dbQuizzes()
        func opts(_ i: Int) -> [String] { q[i].options ?? [] }
        // 어제 — 3NF 문제 1개 오답 (3/4)
        let attempt = QuizAttempt(date: cal.date(byAdding: .day, value: -1, to: now) ?? now,
                                  durationSeconds: 161, answers: [
            pickMC(q[0].question, opts(0), picked: 0, correct: 1),
            pickMC(q[1].question, opts(1), picked: 2, correct: 2),
            pickSA(q[2].question, typed: "제1정규형", correct: "제1정규형", ok: true),
            pickMC(q[3].question, opts(3), picked: 1, correct: 1)
        ])
        return [attempt]
    }

    // MARK: 네트워크 데모 콘텐츠

    private func netContent() -> GeneratedContent {
        GeneratedContent(
            title: "네트워크 개론 1강",
            summaries: [
                GeneratedSummary(
                    title: "OSI 7계층",
                    detail: "네트워크 통신 과정을 7개의 계층으로 나눈 표준 모델이에요.",
                    sections: [
                        defSec("정의", "OSI 7계층은 통신 기능을 물리·데이터링크·네트워크·전송·세션·표현·응용 7단계로 나누어 표준화한 모델이에요.",
                               ["7단계로 나누어 표준화한"]),
                        listSec("주요 계층", ["1계층 물리 — 비트를 신호로 전송", "2계층 데이터링크 — MAC 주소, 프레임",
                                          "3계층 네트워크 — IP 주소, 라우팅", "4계층 전송 — TCP/UDP, 포트", "7계층 응용 — HTTP, DNS"])
                    ]),
                GeneratedSummary(
                    title: "TCP와 UDP",
                    detail: "전송 계층의 두 가지 대표 프로토콜이에요.",
                    sections: [
                        tableSec("비교", ["항목", "TCP", "UDP"],
                                 [["연결", "연결형", "비연결형"], ["신뢰성", "보장", "미보장"], ["속도", "느림", "빠름"]])
                    ])
            ],
            keywords: [
                GeneratedKeyword(title: "OSI 7계층", description: "통신 기능을 7단계로 나눈 표준 모델", related: ["물리", "전송", "응용"]),
                GeneratedKeyword(title: "TCP", description: "신뢰성 있는 연결형 전송 프로토콜", related: ["흐름 제어", "혼잡 제어"]),
                GeneratedKeyword(title: "UDP", description: "빠르지만 비신뢰적인 비연결형 프로토콜", related: ["포트", "스트리밍"]),
                GeneratedKeyword(title: "DNS", description: "도메인 이름을 IP 주소로 변환하는 시스템", related: ["도메인", "IP"])
            ],
            quizzes: netQuizzes())
    }

    private func netQuizzes() -> [GeneratedQuiz] {
        [
            mc("OSI 7계층 중 IP 주소를 다루고 데이터의 경로를 결정하는 계층은?",
               ["데이터 링크 계층", "네트워크 계층", "전송 계층", "응용 계층"], 1,
               "네트워크 계층(3계층)은 IP 주소를 기반으로 라우팅(경로 결정)을 담당해요."),
            mc("TCP의 특징으로 옳은 것은?",
               ["비연결형이다", "데이터 순서를 보장하지 않는다", "흐름 제어와 혼잡 제어를 한다", "헤더가 UDP보다 작다"], 2,
               "TCP는 연결형으로 신뢰성, 흐름 제어, 혼잡 제어를 제공해요."),
            sa("IP 주소를 사람이 읽기 쉬운 도메인 이름으로 변환해 주는 시스템은?",
               "DNS", "DNS(Domain Name System)는 도메인 이름과 IP 주소를 서로 변환해요."),
            mc("OSI 7계층에서 가장 하위(1계층)에 해당하는 것은?",
               ["물리 계층", "데이터 링크 계층", "네트워크 계층", "전송 계층"], 0,
               "1계층은 물리 계층으로 비트를 전기·광 신호로 바꿔 전송해요."),
            mc("UDP에 대한 설명으로 옳은 것은?",
               ["연결을 설정한 뒤 전송한다", "신뢰성과 순서를 보장한다", "헤더가 작고 빠르다", "혼잡 제어를 수행한다"], 2,
               "UDP는 비연결형으로 헤더가 작고 빠르지만 신뢰성은 보장하지 않아요."),
            sa("전송 계층에서 같은 호스트의 여러 응용 프로그램을 구분하기 위해 쓰는 16비트 번호는?",
               "포트", "포트(Port) 번호로 같은 호스트의 여러 응용을 구분해요."),
            mc("HTTP는 OSI 7계층 중 어느 계층에 속하나요?",
               ["전송 계층", "세션 계층", "표현 계층", "응용 계층"], 3,
               "HTTP는 응용 계층(7계층) 프로토콜이에요."),
            mc("IPv4 주소 부족 문제를 해결하기 위해 등장한 128비트 주소 체계는?",
               ["IPv4", "IPv6", "MAC 주소", "ARP"], 1,
               "IPv6는 128비트 주소 체계로 주소 고갈 문제를 해결해요.")
        ]
    }

    /// wrong 집합에 든 문항 번호는 오답으로, 나머지는 정답으로 처리한 응시 기록을 만든다.
    private func netAttempt(date: Date, duration: Int, wrong: Set<Int>) -> QuizAttempt {
        let q = netQuizzes()
        var answers: [AttemptAnswer] = []
        for (i, quiz) in q.enumerated() {
            let isWrong = wrong.contains(i)
            if quiz.type == "short" {
                let correct = quiz.answer ?? ""
                answers.append(pickSA(quiz.question, typed: isWrong ? "잘 모르겠어요" : correct,
                                      correct: correct, ok: !isWrong))
            } else {
                let opts = quiz.options ?? []
                let correctIdx = quiz.correctIndex ?? 0
                let picked = isWrong ? (correctIdx + 1) % max(opts.count, 1) : correctIdx
                answers.append(pickMC(quiz.question, opts, picked: picked, correct: correctIdx))
            }
        }
        return QuizAttempt(date: date, durationSeconds: duration, answers: answers)
    }

    private func netAttempts(now: Date) -> [QuizAttempt] {
        let cal = Calendar.current
        func d(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now) ?? now }
        // 8문항 중 오답을 다양하게 → 오답노트에 q1,q2,q3,q5,q7,q8 (6개) 누적
        return [
            netAttempt(date: d(0), duration: 205, wrong: [2, 7]),      // 6/8
            netAttempt(date: d(1), duration: 188, wrong: [0]),         // 7/8
            netAttempt(date: d(2), duration: 232, wrong: [4, 6]),      // 6/8
            netAttempt(date: d(3), duration: 175, wrong: [1]),         // 7/8
            netAttempt(date: d(4), duration: 260, wrong: [0, 2, 4])    // 5/8
        ]
    }
}
