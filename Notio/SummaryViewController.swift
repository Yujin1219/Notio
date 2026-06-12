//
//  SummaryViewController.swift
//  Notio
//

import UIKit

// MARK: - Models

struct SummaryItem {
    let number: String
    let roman: String
    let title: String
    let detail: String
    let accentColor: UIColor
    let iconBackground: UIColor
}

struct KeywordItem {
    let title: String
    let frequency: Int
    let description: String
    let related: [String]
}

struct QuizQuestion {
    let kind: String
    let question: String
    let options: [String]      // 주관식이면 빈 배열
    let correctIndex: Int       // 주관식이면 -1
    let explanation: String
    let isShort: Bool
    let answer: String          // 주관식 정답 텍스트 (객관식이면 "")

    init(kind: String, question: String, options: [String], correctIndex: Int,
         explanation: String, isShort: Bool = false, answer: String = "") {
        self.kind = kind
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.explanation = explanation
        self.isShort = isShort
        self.answer = answer
    }
}

struct QuizAnswerResult {
    let kind: String          // "객관식" 등 문제 유형
    let question: String
    let myAnswer: String
    let correctAnswer: String
    let isCorrect: Bool
}

struct QuizHistoryEntry {
    let date: String
    let weekday: String
    let score: String
    let badge: String?
    let duration: String
    let percent: Int
    let results: [QuizAnswerResult]
}

struct WrongAnswer {
    let categoryTag: String
    let course: String
    let date: String
    let question: String
    let myAnswer: String
    let correctAnswer: String
    let options: [String]   // 원래 문제의 전체 보기 (객관식 다시 풀기용)
    let correctIndex: Int
    let isShort: Bool        // 주관식 여부
    let answer: String       // 주관식 정답 텍스트
}

// MARK: - View Controller

class SummaryViewController: UIViewController {

    private let noteTitle: String
    private var currentTab: Int = 0
    private var selectedKeywordIndex: Int = 0

    // Quiz state
    private var quizQuestionIndex: Int = 0
    private var quizSelectedIndex: Int? = nil
    private var quizRevealed: Bool = false
    private var quizListMode: Bool = true
    private var quizTypedAnswer: String = ""        // 주관식 입력값
    private weak var quizAnswerField: UITextField?
    private var quizGenTask: Task<Void, Never>?     // 새 문제 생성 작업 (취소용)

    // 실제 응시 기록 기반 통계.
    private var quizStats: (accuracy: Int, total: Int, wrong: Int) {
        let attempts = note?.quizAttempts ?? []
        let total = attempts.reduce(0) { $0 + $1.total }
        let correct = attempts.reduce(0) { $0 + $1.correct }
        let accuracy = total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded())
        return (accuracy, total, total - correct)
    }

    // 실제 응시 기록(최신순)을 화면 모델로 변환.
    private var quizHistory: [QuizHistoryEntry] {
        let attempts = note?.quizAttempts ?? []
        return attempts.enumerated().map { idx, a in
            QuizHistoryEntry(
                date: Self.shortDate(a.date),
                weekday: Self.weekday(a.date),
                score: "\(a.correct)/\(a.total) 정답",
                badge: idx == 0 ? "최근" : nil,
                duration: Self.formatDuration(a.durationSeconds),
                percent: a.percent,
                results: a.answers.map { ans in
                    QuizAnswerResult(
                        kind: ans.isShort == true ? "주관식" : "객관식",
                        question: ans.question,
                        myAnswer: ans.displayMyAnswer,
                        correctAnswer: ans.displayCorrectAnswer,
                        isCorrect: ans.isCorrect)
                })
        }
    }

    // 현재 풀이 중인 퀴즈의 응시 추적용.
    private var quizStartTime: Date?
    private var quizAnswers: [AttemptAnswer] = []

    // 실제 응시 기록에서 틀린 문제만 모아 오답노트로. (문제별 최신 1건, 중복 제거)
    private var wrongAnswers: [WrongAnswer] {
        guard let note else { return [] }
        var seen = Set<String>()
        var result: [WrongAnswer] = []
        for attempt in note.quizAttempts {   // 최신순으로 저장됨
            for ans in attempt.answers where !ans.isCorrect {
                guard !seen.contains(ans.question) else { continue }
                seen.insert(ans.question)
                result.append(WrongAnswer(
                    categoryTag: note.category.rawValue,
                    course: note.title,
                    date: Self.shortDate(attempt.date),
                    question: ans.question,
                    myAnswer: ans.displayMyAnswer,
                    correctAnswer: ans.displayCorrectAnswer,
                    options: ans.options,
                    correctIndex: ans.correctIndex,
                    isShort: ans.isShort == true,
                    answer: ans.correctText ?? ""))
            }
        }
        return result
    }

    // MARK: - 날짜 포맷 헬퍼

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MM.dd"; return f.string(from: date)
    }
    private static func weekday(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "ko_KR"); f.dateFormat = "EEEE"
        return f.string(from: date)
    }
    private static func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60, s = seconds % 60
        return m > 0 ? "\(m)분 \(s)초" : "\(s)초"
    }

    private let initialTab: Int
    private let note: Note?
    private var content: GeneratedContent?
    private var justCreated: Bool

    init(note: Note?, initialTab: Int = 0, justCreated: Bool = false) {
        self.note = note
        self.noteTitle = note?.title ?? "학습 노트"
        self.initialTab = initialTab
        self.content = note?.generatedContent
        self.justCreated = justCreated
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // 실제 콘텐츠가 있으면 그것을, 없으면 샘플을 사용한다.
    private lazy var summaryItems: [SummaryItem] = makeSummaryItems()
    private lazy var keywordItems: [KeywordItem] = makeKeywordItems()
    private lazy var quizQuestions: [QuizQuestion] = makeQuizQuestions()
    private lazy var detailPages: [DetailPage] = makeDetailPages()

    private let sampleSummaryItems: [SummaryItem] = [
        SummaryItem(
            number: "01", roman: "i",
            title: "CPU 스케줄링",
            detail: "프로세스에게 CPU 자원을 배분하는 핵심 OS 기능. 효율적 자원 활용이 목표.",
            accentColor: UIColor(red: 0.42, green: 0.36, blue: 0.62, alpha: 1.0),
            iconBackground: UIColor(red: 0.90, green: 0.86, blue: 0.95, alpha: 1.0)
        ),
        SummaryItem(
            number: "02", roman: "ii",
            title: "선점 vs 비선점",
            detail: "선점형은 강제 CPU 회수 가능, 비선점형은 자발적 반환까지 유지된다.",
            accentColor: UIColor(red: 0.66, green: 0.42, blue: 0.28, alpha: 1.0),
            iconBackground: UIColor(red: 0.96, green: 0.89, blue: 0.82, alpha: 1.0)
        ),
        SummaryItem(
            number: "03", roman: "iii",
            title: "주요 알고리즘",
            detail: "FCFS, SJF, Round Robin, Priority Scheduling 성능 비교가 핵심.",
            accentColor: UIColor(red: 0.34, green: 0.51, blue: 0.27, alpha: 1.0),
            iconBackground: UIColor(red: 0.83, green: 0.90, blue: 0.78, alpha: 1.0)
        ),
    ]

    private let sampleDetailPages: [DetailPage] = [
        DetailPage(sections: [
            ("정의", .definition(
                text: "프로세스 스케줄링은 준비 큐(Ready Queue)에 있는 여러 프로세스 중 어떤 프로세스에게 CPU를 할당할지 결정하는 메커니즘이에요. 좋은 스케줄링은 CPU 활용률을 높이고 응답 시간을 줄여줘요.",
                bolded: ["어떤 프로세스에게 CPU를 할당할지 결정하는 메커니즘"]
            )),
            ("왜 필요한가", .numberedList(items: [
                "CPU는 한정된 자원이고, 동시에 여러 프로세스가 실행을 원해요",
                "공정성과 효율성을 동시에 만족해야 해요",
                "시스템 목표(처리량 / 응답성)에 따라 다른 정책이 필요해요"
            ])),
            ("알고리즘 비교", .table(
                columns: ["알고리즘", "대기 시간", "방식"],
                rows: [
                    ["FCFS", "높음", "비선점"],
                    ["SJF", "낮음", "둘 다"],
                    ["Round Robin", "중간", "선점"],
                    ["Priority", "가변", "둘 다"],
                ]
            )),
        ]),
        DetailPage(sections: [
            ("정의", .definition(
                text: "선점형과 비선점형은 실행 중인 프로세스를 강제로 중단시킬 수 있는지 여부로 나뉘어요. 응답성을 우선하면 선점형, 단순함을 우선하면 비선점형이 어울려요.",
                bolded: ["강제로 중단시킬 수 있는지 여부"]
            )),
            ("핵심 차이", .numberedList(items: [
                "선점형은 우선순위 높은 작업이 오면 즉시 전환해요",
                "비선점형은 현재 작업이 끝나거나 자발적으로 반환할 때까지 기다려요",
                "응답성과 단순성 사이의 트레이드오프가 있어요"
            ])),
            ("방식 비교", .table(
                columns: ["항목", "선점형", "비선점형"],
                rows: [
                    ["응답성", "빠름", "느림"],
                    ["구현", "복잡", "단순"],
                    ["오버헤드", "있음", "거의 없음"],
                    ["예시", "RR, SRTF", "FCFS, SJF"],
                ]
            )),
        ]),
        DetailPage(sections: [
            ("정의", .definition(
                text: "CPU 스케줄링에 자주 쓰이는 대표 알고리즘들이에요. 각각의 목표와 트레이드오프를 알면 상황에 맞는 선택을 할 수 있어요.",
                bolded: ["상황에 맞는 선택"]
            )),
            ("핵심 알고리즘", .numberedList(items: [
                "FCFS — 도착한 순서대로 처리하는 가장 단순한 방식",
                "SJF — 짧은 작업을 우선해 평균 대기 시간을 줄여요",
                "Round Robin — 모든 프로세스에 동일한 시간을 분배해 공정해요",
                "Priority — 우선순위에 따라 처리, 기아 현상 주의가 필요해요"
            ])),
            ("성능 비교", .table(
                columns: ["알고리즘", "장점", "단점"],
                rows: [
                    ["FCFS", "단순함", "긴 작업이 지연"],
                    ["SJF", "최소 대기", "기아 가능"],
                    ["RR", "공정함", "오버헤드"],
                    ["Priority", "유연함", "기아 가능"],
                ]
            )),
        ]),
    ]

    private let sampleKeywordItems: [KeywordItem] = [
        KeywordItem(title: "프로세스 스케줄링", frequency: 15,
                    description: "CPU를 어떤 프로세스에 할당할지 결정하는 OS 메커니즘.",
                    related: ["선점형", "비선점형", "디스패처"]),
        KeywordItem(title: "SJF", frequency: 9,
                    description: "Shortest Job First. 가장 짧은 작업을 먼저 실행하여 평균 대기 시간을 최소화하는 알고리즘.",
                    related: ["FCFS", "선점형", "기아 현상"]),
        KeywordItem(title: "임계 구역", frequency: 7,
                    description: "여러 프로세스가 공유 자원에 접근하는 코드 영역.",
                    related: ["세마포어", "뮤텍스", "경쟁 상태"]),
        KeywordItem(title: "선점형", frequency: 6,
                    description: "실행 중인 프로세스를 강제로 중단시킬 수 있는 스케줄링 방식.",
                    related: ["비선점형", "우선순위"]),
        KeywordItem(title: "FCFS", frequency: 5,
                    description: "First-Come First-Served. 도착한 순서대로 처리하는 알고리즘.",
                    related: ["Round Robin", "SJF"]),
        KeywordItem(title: "Round Robin", frequency: 5,
                    description: "각 프로세스에 동일한 시간 할당량을 부여하는 알고리즘.",
                    related: ["선점형", "타임 슬라이스"]),
        KeywordItem(title: "대기 시간", frequency: 4,
                    description: "프로세스가 준비 큐에서 대기한 총 시간.",
                    related: ["응답 시간", "처리 시간"]),
        KeywordItem(title: "경쟁 상태", frequency: 4,
                    description: "여러 프로세스가 공유 데이터에 동시 접근해 결과가 달라지는 현상.",
                    related: ["임계 구역", "동기화"]),
        KeywordItem(title: "세마포어", frequency: 3,
                    description: "프로세스 동기화에 사용되는 정수형 변수.",
                    related: ["뮤텍스", "P/V 연산"]),
        KeywordItem(title: "Priority", frequency: 3,
                    description: "우선순위에 따라 프로세스를 스케줄링하는 방식.",
                    related: ["기아 현상", "에이징"]),
        KeywordItem(title: "응답 시간", frequency: 2,
                    description: "요청 후 첫 응답까지 걸린 시간.",
                    related: ["대기 시간"]),
    ]

    private let sampleQuizQuestions: [QuizQuestion] = [
        QuizQuestion(
            kind: "예상 문제 · 객관식",
            question: "CPU 스케줄링 알고리즘 중 평균 대기 시간이 가장 짧은 것은?",
            options: [
                "FCFS (First Come First Served)",
                "SJF (Shortest Job First)",
                "라운드 로빈 (Round Robin)",
                "우선순위 스케줄링"
            ],
            correctIndex: 1,
            explanation: "짧은 작업을 먼저 실행하므로 평균 대기 시간이 가장 짧아요. 단, 긴 작업이 무한히 대기하는 starvation 문제가 발생할 수 있어요."
        ),
        QuizQuestion(
            kind: "예상 문제 · 객관식",
            question: "선점형 스케줄링의 가장 큰 특징은?",
            options: [
                "도착한 순서대로 처리한다",
                "실행 중인 프로세스를 강제로 중단시킬 수 있다",
                "모든 작업에 동일한 우선순위를 부여한다",
                "한 번 실행하면 종료까지 CPU를 점유한다"
            ],
            correctIndex: 1,
            explanation: "선점형은 우선순위가 높은 작업이 도착하면 실행 중인 작업을 중단시키고 CPU를 전환해요. 응답성이 좋지만 컨텍스트 스위치 오버헤드가 발생해요."
        ),
        QuizQuestion(
            kind: "예상 문제 · 객관식",
            question: "여러 프로세스가 공유 자원에 동시 접근해 실행 순서에 따라 결과가 달라지는 현상은?",
            options: [
                "교착 상태 (Deadlock)",
                "기아 상태 (Starvation)",
                "경쟁 상태 (Race Condition)",
                "임계 구역 (Critical Section)"
            ],
            correctIndex: 2,
            explanation: "경쟁 상태(Race Condition)는 실행 순서에 따라 결과가 달라지는 문제로, 임계 구역에 대한 동기화(세마포어 등)로 해결해요."
        ),
    ]

    // MARK: - Content mapping (Gemini 결과 → 화면 모델)

    private static let summaryPalette: [(UIColor, UIColor)] = [
        (UIColor(red: 0.42, green: 0.36, blue: 0.62, alpha: 1.0), UIColor(red: 0.90, green: 0.86, blue: 0.95, alpha: 1.0)),
        (UIColor(red: 0.66, green: 0.42, blue: 0.28, alpha: 1.0), UIColor(red: 0.96, green: 0.89, blue: 0.82, alpha: 1.0)),
        (UIColor(red: 0.34, green: 0.51, blue: 0.27, alpha: 1.0), UIColor(red: 0.83, green: 0.90, blue: 0.78, alpha: 1.0)),
        (UIColor(red: 0.30, green: 0.45, blue: 0.62, alpha: 1.0), UIColor(red: 0.84, green: 0.90, blue: 0.96, alpha: 1.0)),
    ]
    private static let romanNumerals = ["i", "ii", "iii", "iv", "v", "vi", "vii", "viii", "ix", "x"]

    private func makeSummaryItems() -> [SummaryItem] {
        guard let content, !content.summaries.isEmpty else { return sampleSummaryItems }
        return content.summaries.enumerated().map { idx, s in
            let palette = Self.summaryPalette[idx % Self.summaryPalette.count]
            return SummaryItem(
                number: String(format: "%02d", idx + 1),
                roman: idx < Self.romanNumerals.count ? Self.romanNumerals[idx] : "\(idx + 1)",
                title: s.title, detail: s.detail,
                accentColor: palette.0, iconBackground: palette.1)
        }
    }

    private func makeKeywordItems() -> [KeywordItem] {
        guard let content, !content.keywords.isEmpty else { return sampleKeywordItems }
        return content.keywords.map {
            KeywordItem(title: $0.title, frequency: max(1, $0.related.count),
                        description: $0.description, related: $0.related)
        }
    }

    private func makeQuizQuestions() -> [QuizQuestion] {
        // 콘텐츠 자체가 없으면(데모 노트) 샘플, 있으면(문제가 비어 있어도) 그대로 사용.
        guard let content else { return sampleQuizQuestions }
        return content.quizzes.map(Self.mapQuiz)
    }

    /// Gemini 퀴즈 → 화면 모델. (객관식/주관식)
    static func mapQuiz(_ q: GeneratedQuiz) -> QuizQuestion {
        if (q.type ?? "multiple") == "short" {
            return QuizQuestion(kind: "예상 문제 · 주관식", question: q.question,
                                options: [], correctIndex: -1, explanation: q.explanation,
                                isShort: true, answer: q.answer ?? "")
        }
        let opts = q.options ?? []
        let upper = max(0, opts.count - 1)
        var safeIndex = min(max(0, q.correctIndex ?? 0), upper)

        // correctIndex가 틀릴 수 있어(0/1-based 혼동 등), 정답 텍스트로 보기를 역매칭해 보정.
        if let answer = q.answer, !answer.isEmpty {
            let target = AnswerMatcher.normalize(answer)
            if let exact = opts.firstIndex(where: { AnswerMatcher.normalize($0) == target }) {
                safeIndex = exact
            } else if let partial = opts.firstIndex(where: {
                let o = AnswerMatcher.normalize($0)
                return !o.isEmpty && (o.contains(target) || target.contains(o))
            }) {
                safeIndex = partial
            }
        }
        return QuizQuestion(kind: "예상 문제 · 객관식", question: q.question,
                            options: opts, correctIndex: safeIndex,
                            explanation: q.explanation, isShort: false, answer: "")
    }

    private func makeDetailPages() -> [DetailPage] {
        guard let content, !content.summaries.isEmpty else { return sampleDetailPages }
        // 요약 항목별로 1페이지씩 생성해 summaryItems와 개수를 맞춘다.
        return content.summaries.map { summary in
            let sections = (summary.sections ?? []).compactMap { Self.mapSection($0, fallbackText: summary.detail) }
            if sections.isEmpty {
                return DetailPage(sections: [("정의", .definition(text: summary.detail, bolded: []))])
            }
            return DetailPage(sections: sections)
        }
    }

    /// Gemini 섹션 → DetailPage 섹션. 형식이 맞지 않으면 nil.
    private static func mapSection(_ s: GeneratedSection,
                                   fallbackText: String) -> (title: String, content: DetailSection)? {
        switch s.type.lowercased() {
        case "list":
            guard let items = s.items, !items.isEmpty else { return nil }
            return (s.heading, .numberedList(items: items))
        case "table":
            guard let columns = s.columns, !columns.isEmpty,
                  let rows = s.rows, !rows.isEmpty else { return nil }
            return (s.heading, .table(columns: columns, rows: rows))
        default: // definition
            let text = (s.text?.isEmpty == false) ? s.text! : fallbackText
            return (s.heading, .definition(text: text, bolded: s.bolded ?? []))
        }
    }

    // MARK: - Shared UI

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.87, green: 0.84, blue: 0.93, alpha: 1.0).cgColor,
            UIColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1.0).cgColor
        ]
        layer.locations = [0.0, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        return layer
    }()

    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        b.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        b.tintColor = .black
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let navTitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .black
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let saveButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        b.setImage(UIImage(systemName: "bookmark", withConfiguration: cfg), for: .normal)
        b.setTitle(" 저장", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        b.tintColor = UIColor(red: 0.42, green: 0.36, blue: 0.62, alpha: 1.0)
        b.setTitleColor(UIColor(red: 0.42, green: 0.36, blue: 0.62, alpha: 1.0), for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let tabSegment = SummaryTabSegment(titles: ["요약", "키워드", "문제"])

    private let quizButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("퀴즈 모드로 이동 →", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor(red: 0.18, green: 0.15, blue: 0.22, alpha: 1.0)
        b.layer.cornerRadius = 28
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Summary tab UI

    private let summaryCountLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        l.textColor = .darkGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let readingTimeLabel: UILabel = {
        let l = UILabel()
        l.text = "읽기 ~2분"
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = .gray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 12
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let nioCard: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        v.layer.cornerRadius = 18
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nioAvatar: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "nio-hi"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nioNameLabel: UILabel = {
        let l = UILabel()
        l.text = "Nio"
        l.font = UIFont.italicSystemFont(ofSize: 13)
        l.textColor = .darkGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nioMessageLabel: UILabel = {
        let l = UILabel()
        l.text = "요약 완성! 이제 퀴즈로 점검해봐요"
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = .darkGray
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    // MARK: - Keyword tab UI

    private let keywordCountLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        l.textColor = .darkGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let keywordHintLabel: UILabel = {
        let l = UILabel()
        l.text = "탭하여 설명 보기"
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = .gray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let chipFlow: FlowLayoutView = {
        let v = FlowLayoutView()
        v.horizontalSpacing = 8
        v.verticalSpacing = 10
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var chipButtons: [KeywordChipButton] = []
    private let keywordDetailCard = KeywordDetailCard()

    // MARK: - Quiz tab UI

    // 퀴즈 진행 바 (문항 수만큼 채워지며 %를 표시)
    private let quizProgressLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        l.textColor = UIColor(white: 0.4, alpha: 1.0)
        l.textAlignment = .right
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let quizProgressTrack: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(white: 0.0, alpha: 0.08)
        v.layer.cornerRadius = 3
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let quizProgressFill: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)
        v.layer.cornerRadius = 3
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private var quizProgressFillWidth: NSLayoutConstraint?

    private lazy var quizProgressBar: UIView = {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(quizProgressLabel)
        container.addSubview(quizProgressTrack)
        quizProgressTrack.addSubview(quizProgressFill)

        let fillWidth = quizProgressFill.widthAnchor.constraint(equalTo: quizProgressTrack.widthAnchor, multiplier: 0.0)
        quizProgressFillWidth = fillWidth

        NSLayoutConstraint.activate([
            quizProgressLabel.topAnchor.constraint(equalTo: container.topAnchor),
            quizProgressLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            quizProgressLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),

            quizProgressTrack.topAnchor.constraint(equalTo: quizProgressLabel.bottomAnchor, constant: 6),
            quizProgressTrack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            quizProgressTrack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            quizProgressTrack.heightAnchor.constraint(equalToConstant: 6),
            quizProgressTrack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            quizProgressFill.leadingAnchor.constraint(equalTo: quizProgressTrack.leadingAnchor),
            quizProgressFill.topAnchor.constraint(equalTo: quizProgressTrack.topAnchor),
            quizProgressFill.bottomAnchor.constraint(equalTo: quizProgressTrack.bottomAnchor),
            fillWidth,
        ])
        return container
    }()

    private var quizOptionViews: [QuizOptionView] = []

    // MARK: - Lifecycle

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if justCreated {
            justCreated = false
            showToast("노트가 생성됐어요")
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        navTitleLabel.text = noteTitle
        summaryCountLabel.text = "핵심 요약 · \(summaryItems.count)개"
        keywordCountLabel.text = "핵심 키워드 · \(keywordItems.count)개"

        setupLayout()
        populateSummary()
        populateKeywordChips()
        tabSegment.setSelected(initialTab)
        applyTab(initialTab)

        tabSegment.onChange = { [weak self] index in
            self?.applyTab(index)
        }

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        quizButton.addTarget(self, action: #selector(quizTapped), for: .touchUpInside)
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        updateSaveButton(note?.isFavorite ?? false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
        updateKeywordPointer()
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(backButton)
        view.addSubview(navTitleLabel)
        view.addSubview(saveButton)
        view.addSubview(tabSegment)

        // Summary tab
        view.addSubview(summaryCountLabel)
        view.addSubview(readingTimeLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(nioCard)
        nioCard.addSubview(nioAvatar)
        nioCard.addSubview(nioNameLabel)
        nioCard.addSubview(nioMessageLabel)

        // Keyword tab
        view.addSubview(keywordCountLabel)
        view.addSubview(keywordHintLabel)
        view.addSubview(chipFlow)
        view.addSubview(keywordDetailCard)
        keywordDetailCard.translatesAutoresizingMaskIntoConstraints = false

        // Quiz tab
        view.addSubview(quizProgressBar)

        view.addSubview(quizButton)

        tabSegment.translatesAutoresizingMaskIntoConstraints = false

        // 제목은 화면 중앙에 두되, 길면 좌우 버튼 사이에서 말줄임 처리.
        navTitleLabel.lineBreakMode = .byTruncatingTail
        navTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let titleCenterX = navTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        titleCenterX.priority = .defaultHigh

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            navTitleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            titleCenterX,
            navTitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: backButton.trailingAnchor, constant: 8),
            navTitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: saveButton.leadingAnchor, constant: -8),

            saveButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            saveButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            tabSegment.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 16),
            tabSegment.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabSegment.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabSegment.heightAnchor.constraint(equalToConstant: 44),

            // 요약 tab
            summaryCountLabel.topAnchor.constraint(equalTo: tabSegment.bottomAnchor, constant: 16),
            summaryCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            readingTimeLabel.centerYAnchor.constraint(equalTo: summaryCountLabel.centerYAnchor),
            readingTimeLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            scrollView.topAnchor.constraint(equalTo: summaryCountLabel.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: nioCard.topAnchor, constant: -10),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            nioCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nioCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nioCard.bottomAnchor.constraint(equalTo: quizButton.topAnchor, constant: -14),

            nioAvatar.leadingAnchor.constraint(equalTo: nioCard.leadingAnchor, constant: 12),
            nioAvatar.centerYAnchor.constraint(equalTo: nioCard.centerYAnchor),
            nioAvatar.widthAnchor.constraint(equalToConstant: 40),
            nioAvatar.heightAnchor.constraint(equalToConstant: 40),

            nioNameLabel.topAnchor.constraint(equalTo: nioCard.topAnchor, constant: 14),
            nioNameLabel.leadingAnchor.constraint(equalTo: nioAvatar.trailingAnchor, constant: 10),

            nioMessageLabel.topAnchor.constraint(equalTo: nioNameLabel.bottomAnchor, constant: 2),
            nioMessageLabel.leadingAnchor.constraint(equalTo: nioAvatar.trailingAnchor, constant: 10),
            nioMessageLabel.trailingAnchor.constraint(equalTo: nioCard.trailingAnchor, constant: -12),
            nioMessageLabel.bottomAnchor.constraint(equalTo: nioCard.bottomAnchor, constant: -14),

            // 문제 tab - progress pills
            quizProgressBar.topAnchor.constraint(equalTo: tabSegment.bottomAnchor, constant: 16),
            quizProgressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            quizProgressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            // 키워드 tab
            keywordCountLabel.topAnchor.constraint(equalTo: tabSegment.bottomAnchor, constant: 16),
            keywordCountLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            keywordHintLabel.centerYAnchor.constraint(equalTo: keywordCountLabel.centerYAnchor),
            keywordHintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            chipFlow.topAnchor.constraint(equalTo: keywordCountLabel.bottomAnchor, constant: 14),
            chipFlow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            chipFlow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            keywordDetailCard.topAnchor.constraint(equalTo: chipFlow.bottomAnchor, constant: 14),
            keywordDetailCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            keywordDetailCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            quizButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            quizButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            quizButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            quizButton.heightAnchor.constraint(equalToConstant: 56),
        ])
    }

    private func populateSummary() {
        if let text = note?.sourceText, !text.isEmpty {
            contentStack.addArrangedSubview(makeSourceTextRow())
        }
        for (index, item) in summaryItems.enumerated() {
            let card = SummaryCardView(item: item)
            card.onDetailTapped = { [weak self] in
                self?.showDetail(at: index)
            }
            contentStack.addArrangedSubview(card)
        }
    }

    private func makeSourceTextRow() -> UIView {
        let card = UIControl()
        card.addTarget(self, action: #selector(sourceTextTapped), for: .touchUpInside)
        card.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "doc.plaintext",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)))
        icon.tintColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        icon.isUserInteractionEnabled = false
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "원문 텍스트 보기"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .black
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        arrow.tintColor = UIColor(white: 0.7, alpha: 1.0)
        arrow.isUserInteractionEnabled = false
        arrow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(label)
        card.addSubview(arrow)
        NSLayoutConstraint.activate([
            card.heightAnchor.constraint(equalToConstant: 48),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            icon.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            arrow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            arrow.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    @objc private func sourceTextTapped() {
        guard let text = note?.sourceText, !text.isEmpty else { return }
        let vc = SourceTextViewController(noteTitle: noteTitle, sourceText: text)
        navigationController?.pushViewController(vc, animated: true)
    }

    private func showDetail(at index: Int) {
        let detailVC = SummaryDetailViewController(
            items: summaryItems,
            pages: detailPages,
            startIndex: index
        )
        navigationController?.pushViewController(detailVC, animated: true)
    }

    private func populateKeywordChips() {
        for (i, item) in keywordItems.enumerated() {
            let chip = KeywordChipButton()
            chip.setTitle(item.title, for: .normal)
            chip.tag = i
            chip.addTarget(self, action: #selector(keywordChipTapped(_:)), for: .touchUpInside)
            chipFlow.addSubview(chip)
            chipButtons.append(chip)
        }
        refreshChipStyles()
        keywordDetailCard.configure(item: keywordItems[selectedKeywordIndex])
    }

    private func refreshChipStyles() {
        for (i, chip) in chipButtons.enumerated() {
            chip.styleType = (i == selectedKeywordIndex) ? .selected : .normal
        }
    }

    private func updateKeywordPointer() {
        guard currentTab == 1,
              selectedKeywordIndex < chipButtons.count,
              chipFlow.bounds.width > 0 else { return }
        let chip = chipButtons[selectedKeywordIndex]
        let chipCenterInView = chipFlow.convert(CGPoint(x: chip.frame.midX, y: 0), to: view)
        let cardOriginX = keywordDetailCard.frame.minX
        let pointerX = chipCenterInView.x - cardOriginX
        keywordDetailCard.setPointerCenterX(pointerX)
    }

    // MARK: - Tab switching

    private func applyTab(_ index: Int) {
        currentTab = index
        let isSummary = index == 0
        let isKeywords = index == 1
        let isQuiz = index == 2

        summaryCountLabel.isHidden = !isSummary
        readingTimeLabel.isHidden = !isSummary
        scrollView.isHidden = !(isSummary || isQuiz)
        nioCard.isHidden = !isSummary

        keywordCountLabel.isHidden = !isKeywords
        keywordHintLabel.isHidden = !isKeywords
        chipFlow.isHidden = !isKeywords
        keywordDetailCard.isHidden = !isKeywords

        quizProgressBar.isHidden = !(isQuiz && !quizListMode)

        // Rebuild scroll content
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if isSummary {
            populateSummary()
        } else if isQuiz {
            if quizListMode {
                renderQuizList()
            } else {
                renderQuizQuestion()
            }
        }

        // Bottom button label
        if isQuiz {
            quizButton.setTitle(quizListMode ? "새 퀴즈 시작하기 →" : "다음 문제 →", for: .normal)
        } else {
            quizButton.setTitle("퀴즈 모드로 이동 →", for: .normal)
        }

        if isKeywords {
            view.setNeedsLayout()
            view.layoutIfNeeded()
            updateKeywordPointer()
        }
    }

    // MARK: - Quiz

    private func renderQuizQuestion() {
        guard quizQuestionIndex < quizQuestions.count else { return }
        // 이전 문제 카드를 비우고 현재 문제만 보이게 한다. (다음 문제 누적 방지)
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let q = quizQuestions[quizQuestionIndex]
        updateQuizPills()

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        let kindLabel = UILabel()
        kindLabel.text = q.kind
        kindLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        kindLabel.textColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        kindLabel.translatesAutoresizingMaskIntoConstraints = false

        let questionLabel = UILabel()
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 5
        questionLabel.attributedText = NSAttributedString(string: q.question, attributes: [
            .font: UIFont.systemFont(ofSize: 19, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: para
        ])
        questionLabel.numberOfLines = 0
        questionLabel.translatesAutoresizingMaskIntoConstraints = false

        let optionsStack = UIStackView()
        optionsStack.axis = .vertical
        optionsStack.spacing = 10
        optionsStack.translatesAutoresizingMaskIntoConstraints = false

        quizOptionViews.removeAll()
        quizAnswerField = nil
        if q.isShort {
            optionsStack.addArrangedSubview(makeShortAnswerView(for: q))
        } else {
            for (i, text) in q.options.enumerated() {
                let option = QuizOptionView(number: i + 1, text: text)
                option.addAction(UIAction { [weak self] _ in
                    self?.handleOptionTap(index: i)
                }, for: .touchUpInside)
                option.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
                optionsStack.addArrangedSubview(option)
                quizOptionViews.append(option)
            }
        }

        card.addSubview(kindLabel)
        card.addSubview(questionLabel)
        card.addSubview(optionsStack)

        let explanationView = makeQuizExplanationView(for: q)
        explanationView.isHidden = !quizRevealed
        explanationView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(explanationView)

        NSLayoutConstraint.activate([
            kindLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            kindLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            kindLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            questionLabel.topAnchor.constraint(equalTo: kindLabel.bottomAnchor, constant: 8),
            questionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            questionLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            optionsStack.topAnchor.constraint(equalTo: questionLabel.bottomAnchor, constant: 18),
            optionsStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            optionsStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),

            explanationView.topAnchor.constraint(equalTo: optionsStack.bottomAnchor, constant: quizRevealed ? 16 : 0),
            explanationView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            explanationView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            explanationView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),
        ])

        contentStack.addArrangedSubview(card)
        refreshQuizOptionStyles()
    }

    private func makeShortAnswerView(for q: QuizQuestion) -> UIView {
        let field = PaddedTextField()
        field.placeholder = "정답을 입력하세요"
        field.text = quizTypedAnswer
        field.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        field.backgroundColor = .white
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1.5
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.isEnabled = !quizRevealed
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 54).isActive = true
        field.addTarget(self, action: #selector(shortAnswerChanged(_:)), for: .editingChanged)

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "정답 확인", style: .done, target: self, action: #selector(quizTapped))
        ]
        field.inputAccessoryView = toolbar

        if quizRevealed {
            let correct = AnswerMatcher.isCorrect(typed: quizTypedAnswer, correct: q.answer)
            let green = UIColor(red: 0.30, green: 0.62, blue: 0.40, alpha: 1.0)
            let red = UIColor(red: 0.82, green: 0.40, blue: 0.38, alpha: 1.0)
            field.layer.borderColor = (correct ? green : red).cgColor
            field.backgroundColor = correct
                ? UIColor(red: 0.89, green: 0.95, blue: 0.87, alpha: 1.0)
                : UIColor(red: 0.99, green: 0.93, blue: 0.91, alpha: 1.0)
        } else {
            field.layer.borderColor = UIColor(white: 0.85, alpha: 1.0).cgColor
        }

        quizAnswerField = field
        return field
    }

    @objc private func shortAnswerChanged(_ sender: UITextField) {
        quizTypedAnswer = sender.text ?? ""
    }

    @objc private func dismissQuizKeyboard() { view.endEditing(true) }

    private func makeQuizExplanationView(for question: QuizQuestion) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.88, green: 0.95, blue: 0.85, alpha: 1.0)
        container.layer.cornerRadius = 14
        container.layer.borderWidth = 1
        container.layer.borderColor = UIColor(red: 0.55, green: 0.78, blue: 0.55, alpha: 0.5).cgColor

        let icon = UIImageView(image: UIImage(systemName: "checkmark.circle.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)))
        icon.tintColor = UIColor(red: 0.34, green: 0.62, blue: 0.40, alpha: 1.0)
        icon.translatesAutoresizingMaskIntoConstraints = false

        let answerLabel = UILabel()
        let prefix = NSAttributedString(string: "정답  ", attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor(red: 0.30, green: 0.50, blue: 0.32, alpha: 1.0)
        ])
        let correctString: String
        if question.isShort {
            correctString = question.answer
        } else if question.options.indices.contains(question.correctIndex) {
            correctString = "\(circledNumber(question.correctIndex + 1)) " + question.options[question.correctIndex]
        } else {
            correctString = "-"
        }
        let italicFont = UIFont(name: "Georgia-BoldItalic", size: 14)
            ?? UIFont.italicSystemFont(ofSize: 14)
        let correctText = NSMutableAttributedString(string: correctString,
                                                    attributes: [
                                                        .font: italicFont,
                                                        .foregroundColor: UIColor.black
                                                    ])
        let combined = NSMutableAttributedString()
        combined.append(prefix)
        combined.append(correctText)
        answerLabel.attributedText = combined
        answerLabel.numberOfLines = 0
        answerLabel.translatesAutoresizingMaskIntoConstraints = false

        let bodyLabel = UILabel()
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        bodyLabel.attributedText = NSAttributedString(string: question.explanation, attributes: [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor(white: 0.25, alpha: 1.0),
            .paragraphStyle: para
        ])
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(icon)
        container.addSubview(answerLabel)
        container.addSubview(bodyLabel)

        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: container.topAnchor, constant: 14),
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20),

            answerLabel.topAnchor.constraint(equalTo: icon.topAnchor),
            answerLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            answerLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),

            bodyLabel.topAnchor.constraint(equalTo: answerLabel.bottomAnchor, constant: 8),
            bodyLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 14),
            bodyLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -14),
            bodyLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -14),
        ])
        return container
    }

    private func updateQuizPills() {
        let total = max(quizQuestions.count, 1)
        let current = min(quizQuestionIndex + 1, total)
        let ratio = CGFloat(current) / CGFloat(total)
        quizProgressLabel.text = "\(current) / \(total)  ·  \(Int((ratio * 100).rounded()))%"

        // 진행 비율만큼 채움 바 너비를 갱신. (multiplier는 변경 불가라 재생성)
        quizProgressFillWidth?.isActive = false
        quizProgressFillWidth = quizProgressFill.widthAnchor.constraint(
            equalTo: quizProgressTrack.widthAnchor, multiplier: ratio)
        quizProgressFillWidth?.isActive = true
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    private func refreshQuizOptionStyles() {
        guard quizQuestionIndex < quizQuestions.count else { return }
        let q = quizQuestions[quizQuestionIndex]
        for (i, opt) in quizOptionViews.enumerated() {
            if quizRevealed {
                if i == q.correctIndex {
                    opt.displayState = .correct
                } else if i == quizSelectedIndex {
                    opt.displayState = .incorrect
                } else {
                    opt.displayState = .normal
                }
                opt.isEnabled = false
            } else {
                opt.displayState = (i == quizSelectedIndex) ? .selected : .normal
                opt.isEnabled = true
            }
        }
    }

    private func handleOptionTap(index: Int) {
        guard !quizRevealed else { return }
        quizSelectedIndex = index
        refreshQuizOptionStyles()
    }

    private func handleQuizNext() {
        guard quizQuestionIndex < quizQuestions.count else { return }
        let q = quizQuestions[quizQuestionIndex]
        if !quizRevealed {
            // 응답했는지 확인 (객관식: 보기 선택 / 주관식: 텍스트 입력)
            if q.isShort {
                view.endEditing(true)
                guard !quizTypedAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            } else {
                guard quizSelectedIndex != nil else { return }
            }
            quizRevealed = true
            recordCurrentAnswer()
            renderQuizQuestion()
            // Scroll down to show explanation
            DispatchQueue.main.async {
                let bottom = self.scrollView.contentSize.height - self.scrollView.bounds.height
                if bottom > 0 {
                    self.scrollView.setContentOffset(CGPoint(x: 0, y: bottom), animated: true)
                }
            }
        } else if quizQuestionIndex < quizQuestions.count - 1 {
            quizQuestionIndex += 1
            quizSelectedIndex = nil
            quizTypedAnswer = ""
            quizRevealed = false
            renderQuizQuestion()
            scrollView.setContentOffset(.zero, animated: false)
        } else {
            // Quiz complete → 응시 기록 저장 후 목록으로
            saveQuizAttempt()
            quizListMode = true
            quizQuestionIndex = 0
            quizSelectedIndex = nil
            quizTypedAnswer = ""
            quizRevealed = false
            applyTab(2)
            scrollView.setContentOffset(.zero, animated: false)
        }
    }

    /// 현재 문제의 응답을 기록한다. (정답 확인 시 1회)
    private func recordCurrentAnswer() {
        guard quizAnswers.count == quizQuestionIndex,
              quizQuestionIndex < quizQuestions.count else { return }
        let q = quizQuestions[quizQuestionIndex]
        if q.isShort {
            let correct = AnswerMatcher.isCorrect(typed: quizTypedAnswer, correct: q.answer)
            quizAnswers.append(AttemptAnswer(question: q.question, options: [],
                                             selectedIndex: -1, correctIndex: -1,
                                             isShort: true, typedAnswer: quizTypedAnswer,
                                             correctText: q.answer, correctFlag: correct))
        } else {
            quizAnswers.append(AttemptAnswer(question: q.question, options: q.options,
                                             selectedIndex: quizSelectedIndex ?? -1, correctIndex: q.correctIndex))
        }
    }

    /// 완료된 퀴즈를 노트에 영속 저장한다.
    private func saveQuizAttempt() {
        guard let note, !quizAnswers.isEmpty else { return }
        let duration = Int(Date().timeIntervalSince(quizStartTime ?? Date()))
        let attempt = QuizAttempt(date: Date(), durationSeconds: max(duration, 0), answers: quizAnswers)
        DataStore.shared.addQuizAttempt(attempt, to: note)
    }

    // MARK: - Quiz list

    private func renderQuizList() {
        contentStack.addArrangedSubview(makeStatsCard())
        contentStack.addArrangedSubview(makeNewQuizCard())
        contentStack.addArrangedSubview(makeMistakeNotebookRow())
        contentStack.addArrangedSubview(makeHistoryHeader())
        let history = quizHistory
        if history.isEmpty {
            contentStack.addArrangedSubview(makeEmptyHistoryRow())
        } else {
            for (index, entry) in history.enumerated() {
                contentStack.addArrangedSubview(makeHistoryRow(entry: entry, index: index))
            }
        }
    }

    private func makeEmptyHistoryRow() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = "아직 푼 퀴즈가 없어요.\n위에서 문제를 풀면 기록이 쌓여요."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 22),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -22),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        return card
    }

    private func makeStatsCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        card.translatesAutoresizingMaskIntoConstraints = false

        let header = UILabel()
        header.text = "나의 학습 현황"
        header.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        header.textColor = .gray
        header.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(makeStatItem(value: "\(quizStats.accuracy)%", suffix: "정답률",
                                              valueColor: .black, suffixColor: .gray))
        stack.addArrangedSubview(makeStatItem(value: "\(quizStats.total)", suffix: "푼 문제",
                                              valueColor: .black, suffixColor: .gray))
        stack.addArrangedSubview(makeStatItem(value: "\(quizStats.wrong)", suffix: "오답",
                                              valueColor: UIColor(red: 0.86, green: 0.55, blue: 0.30, alpha: 1.0),
                                              suffixColor: .gray))

        card.addSubview(header)
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            header.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),

            stack.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeStatItem(value: String, suffix: String,
                              valueColor: UIColor, suffixColor: UIColor) -> UIView {
        let container = UIView()
        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        valueLabel.textColor = valueColor
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        let suffixLabel = UILabel()
        suffixLabel.text = suffix
        suffixLabel.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        suffixLabel.textColor = suffixColor
        suffixLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(valueLabel)
        container.addSubview(suffixLabel)
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: container.topAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            suffixLabel.lastBaselineAnchor.constraint(equalTo: valueLabel.lastBaselineAnchor),
            suffixLabel.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 4),
            suffixLabel.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
        ])
        return container
    }

    private func makeNewQuizCard() -> UIView {
        let card = DashedBorderView()
        card.backgroundColor = UIColor(red: 0.95, green: 0.92, blue: 0.98, alpha: 1.0)
        card.configure(strokeColor: UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0),
                       lineWidth: 1.5,
                       dashPattern: [4, 4],
                       cornerRadius: 16)
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconCircle = UIView()
        iconCircle.backgroundColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        iconCircle.layer.cornerRadius = 22
        iconCircle.translatesAutoresizingMaskIntoConstraints = false

        let plus = UIImageView(image: UIImage(systemName: "plus",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold)))
        plus.tintColor = .white
        plus.contentMode = .center
        plus.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.addSubview(plus)

        let title = UILabel()
        title.text = "새 퀴즈 만들기"
        title.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        title.textColor = .black
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "난이도와 문제 수를 정해 AI가 새 문제를 만들어요"
        subtitle.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(systemName: "arrow.right",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        arrow.tintColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        arrow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconCircle)
        card.addSubview(title)
        card.addSubview(subtitle)
        card.addSubview(arrow)

        let tap = UITapGestureRecognizer(target: self, action: #selector(newQuizCardTapped))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            iconCircle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconCircle.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 44),
            iconCircle.heightAnchor.constraint(equalToConstant: 44),

            plus.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            plus.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            title.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 14),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 4),
            subtitle.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 14),
            subtitle.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),

            arrow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            arrow.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    @objc private func newQuizCardTapped() {
        let config = NewQuizConfigViewController()
        config.onGenerate = { [weak self] difficulty, count in
            self?.generateNewQuiz(difficulty: difficulty, count: count)
        }
        if let sheet = config.sheetPresentationController {
            sheet.detents = [.medium()]
            sheet.prefersGrabberVisible = true
        }
        present(config, animated: true)
    }

    private func generateNewQuiz(difficulty: QuizDifficulty, count: Int) {
        let loading = makeLoadingAlert("AI가 \(count)문제를 만드는 중...")
        // 생성 도중 취소하고 이전 화면으로 돌아갈 수 있게.
        loading.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
            self?.quizGenTask?.cancel()
        })
        present(loading, animated: true)

        quizGenTask = Task { @MainActor in
            do {
                let quizzes = try await GeminiService.shared.generateQuizzes(
                    topic: noteTitle,
                    summaries: content?.summaries ?? [],
                    keywords: content?.keywords ?? [],
                    difficulty: difficulty, count: count,
                    avoiding: content?.quizzes.map(\.question) ?? [])
                if Task.isCancelled { return }
                loading.dismiss(animated: true) {
                    guard !quizzes.isEmpty else {
                        self.showQuizAlert("문제를 만들지 못했어요. 다시 시도해주세요.")
                        return
                    }
                    self.applyRegeneratedQuizzes(quizzes)
                    self.showToast("문제 \(quizzes.count)개를 만들었어요")
                    self.startQuiz()
                }
            } catch {
                if Task.isCancelled || error is CancellationError { return }   // 취소는 조용히
                loading.dismiss(animated: true) {
                    let msg = (error as? GeminiError)?.errorDescription ?? error.localizedDescription
                    self.showQuizAlert(msg)
                }
            }
        }
    }

    /// 새로 만든 퀴즈를 화면에 반영하고 노트에 저장한다.
    private func applyRegeneratedQuizzes(_ quizzes: [GeneratedQuiz]) {
        quizQuestions = quizzes.map(Self.mapQuiz)

        let updated = GeneratedContent(
            title: content?.title ?? noteTitle,
            summaries: content?.summaries ?? [],
            keywords: content?.keywords ?? [],
            quizzes: quizzes)
        content = updated

        if let note,
           let data = try? JSONEncoder().encode(updated),
           let json = String(data: data, encoding: .utf8) {
            note.contentJSON = json
            DataStore.shared.save()
        }
    }

    private func makeLoadingAlert(_ message: String) -> UIAlertController {
        let alert = UIAlertController(title: nil, message: "\(message)\n\n", preferredStyle: .alert)
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        alert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: alert.view.centerXAnchor),
            spinner.bottomAnchor.constraint(equalTo: alert.view.bottomAnchor, constant: -20),
        ])
        return alert
    }

    private func showQuizAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    private func makeMistakeNotebookRow() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        card.translatesAutoresizingMaskIntoConstraints = false

        let iconBg = UIView()
        iconBg.backgroundColor = UIColor(red: 0.96, green: 0.89, blue: 0.78, alpha: 1.0)
        iconBg.layer.cornerRadius = 12
        iconBg.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: "doc.text",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)))
        icon.tintColor = UIColor(red: 0.66, green: 0.45, blue: 0.20, alpha: 1.0)
        icon.contentMode = .center
        icon.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(icon)

        let title = UILabel()
        title.text = "오답노트"
        title.font = UIFont.systemFont(ofSize: 15, weight: .bold)
        title.textColor = .black
        title.translatesAutoresizingMaskIntoConstraints = false

        let badge = PaddedLabel()
        badge.text = "\(wrongAnswers.count)"
        badge.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        badge.textColor = .white
        badge.backgroundColor = UIColor(red: 0.86, green: 0.45, blue: 0.40, alpha: 1.0)
        badge.padding = UIEdgeInsets(top: 2, left: 7, bottom: 2, right: 7)
        badge.layer.cornerRadius = 9
        badge.layer.masksToBounds = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "틀린 문제만 모아서 복습하기"
        subtitle.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        subtitle.textColor = .gray
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold)))
        arrow.tintColor = UIColor(white: 0.6, alpha: 1.0)
        arrow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconBg)
        card.addSubview(title)
        card.addSubview(badge)
        card.addSubview(subtitle)
        card.addSubview(arrow)

        let tap = UITapGestureRecognizer(target: self, action: #selector(mistakeNotebookTapped))
        card.addGestureRecognizer(tap)
        card.isUserInteractionEnabled = true

        NSLayoutConstraint.activate([
            iconBg.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            iconBg.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            iconBg.widthAnchor.constraint(equalToConstant: 40),
            iconBg.heightAnchor.constraint(equalToConstant: 40),

            icon.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),

            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            title.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),

            badge.leadingAnchor.constraint(equalTo: title.trailingAnchor, constant: 8),
            badge.centerYAnchor.constraint(equalTo: title.centerYAnchor),
            badge.heightAnchor.constraint(equalToConstant: 18),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            subtitle.leadingAnchor.constraint(equalTo: iconBg.trailingAnchor, constant: 12),
            subtitle.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            arrow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            arrow.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    @objc private func mistakeNotebookTapped() { showMistakeNotebook() }

    private func makeHistoryHeader() -> UIView {
        let container = UIView()
        let left = UILabel()
        left.text = "퀴즈 기록 · \(quizHistory.count)회"
        left.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        left.textColor = .gray
        left.translatesAutoresizingMaskIntoConstraints = false
        let right = UILabel()
        right.text = "최신순"
        right.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        right.textColor = UIColor(white: 0.55, alpha: 1.0)
        right.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(left)
        container.addSubview(right)
        NSLayoutConstraint.activate([
            left.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            left.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            left.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
            right.centerYAnchor.constraint(equalTo: left.centerYAnchor),
            right.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),
        ])
        return container
    }

    private func makeHistoryRow(entry: QuizHistoryEntry, index: Int) -> UIView {
        let card = UIControl()
        card.tag = index
        card.addTarget(self, action: #selector(historyRowTapped(_:)), for: .touchUpInside)
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 5
        card.translatesAutoresizingMaskIntoConstraints = false

        let dateLabel = UILabel()
        dateLabel.text = entry.date
        dateLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        dateLabel.textColor = .black
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        let weekdayLabel = UILabel()
        weekdayLabel.text = entry.weekday
        weekdayLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        weekdayLabel.textColor = .gray
        weekdayLabel.translatesAutoresizingMaskIntoConstraints = false

        let scoreLabel = UILabel()
        scoreLabel.text = entry.score
        scoreLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        scoreLabel.textColor = .black
        scoreLabel.translatesAutoresizingMaskIntoConstraints = false

        let clock = UIImageView(image: UIImage(systemName: "clock",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .medium)))
        clock.tintColor = .gray
        clock.translatesAutoresizingMaskIntoConstraints = false

        let durationLabel = UILabel()
        let percentColor = percentColor(for: entry.percent)
        let combined = NSMutableAttributedString(string: "\(entry.duration)  · ", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .regular),
            .foregroundColor: UIColor.gray
        ])
        combined.append(NSAttributedString(string: "\(entry.percent)%", attributes: [
            .font: UIFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: percentColor
        ]))
        durationLabel.attributedText = combined
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        let arrow = UIImageView(image: UIImage(systemName: "chevron.right",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        arrow.tintColor = UIColor(white: 0.7, alpha: 1.0)
        arrow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(dateLabel)
        card.addSubview(weekdayLabel)
        card.addSubview(scoreLabel)
        card.addSubview(clock)
        card.addSubview(durationLabel)
        card.addSubview(arrow)

        var horizontalRefs: [NSLayoutConstraint] = []

        if let badgeText = entry.badge {
            let badge = PaddedLabel()
            badge.text = badgeText
            badge.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
            badge.textColor = UIColor(white: 0.45, alpha: 1.0)
            badge.backgroundColor = UIColor(white: 0.93, alpha: 1.0)
            badge.padding = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
            badge.layer.cornerRadius = 9
            badge.layer.masksToBounds = true
            badge.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(badge)
            horizontalRefs.append(contentsOf: [
                badge.leadingAnchor.constraint(equalTo: scoreLabel.trailingAnchor, constant: 8),
                badge.centerYAnchor.constraint(equalTo: scoreLabel.centerYAnchor),
                badge.heightAnchor.constraint(equalToConstant: 18),
            ])
        }

        NSLayoutConstraint.activate([
            dateLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            dateLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),

            weekdayLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 1),
            weekdayLabel.leadingAnchor.constraint(equalTo: dateLabel.leadingAnchor),
            weekdayLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),

            scoreLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            scoreLabel.leadingAnchor.constraint(equalTo: dateLabel.trailingAnchor, constant: 28),

            clock.topAnchor.constraint(equalTo: scoreLabel.bottomAnchor, constant: 6),
            clock.leadingAnchor.constraint(equalTo: scoreLabel.leadingAnchor),
            clock.widthAnchor.constraint(equalToConstant: 12),
            clock.heightAnchor.constraint(equalToConstant: 12),

            durationLabel.centerYAnchor.constraint(equalTo: clock.centerYAnchor),
            durationLabel.leadingAnchor.constraint(equalTo: clock.trailingAnchor, constant: 4),

            arrow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            arrow.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ] + horizontalRefs)

        return card
    }

    private func percentColor(for percent: Int) -> UIColor {
        if percent >= 100 {
            return UIColor(red: 0.30, green: 0.62, blue: 0.40, alpha: 1.0) // green
        } else if percent >= 80 {
            return UIColor(red: 0.30, green: 0.45, blue: 0.85, alpha: 1.0) // blue
        } else if percent >= 60 {
            return UIColor(red: 0.86, green: 0.55, blue: 0.30, alpha: 1.0) // orange
        } else {
            return UIColor(red: 0.82, green: 0.40, blue: 0.38, alpha: 1.0) // red
        }
    }

    private func circledNumber(_ n: Int) -> String {
        switch n {
        case 1: return "①"
        case 2: return "②"
        case 3: return "③"
        case 4: return "④"
        default: return "\(n)"
        }
    }

    // MARK: - Actions

    @objc private func backTapped() { goBack() }

    @objc private func quizTapped() {
        if currentTab == 2 {
            if quizListMode {
                startQuiz()
            } else {
                handleQuizNext()
            }
        } else {
            tabSegment.setSelected(2)
            applyTab(2)
        }
    }

    private func startQuiz() {
        // 풀 문제가 없으면 새 문제 만들기로 안내.
        guard !quizQuestions.isEmpty else {
            newQuizCardTapped()
            return
        }
        quizListMode = false
        quizQuestionIndex = 0
        quizSelectedIndex = nil
        quizTypedAnswer = ""
        quizRevealed = false
        quizStartTime = Date()
        quizAnswers = []
        applyTab(2)
        scrollView.setContentOffset(.zero, animated: false)
    }

    private func showMistakeNotebook() {
        let vc = WrongAnswerNotebookViewController(wrongAnswers: wrongAnswers)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func historyRowTapped(_ sender: UIControl) {
        guard quizHistory.indices.contains(sender.tag) else { return }
        let vc = QuizHistoryDetailViewController(entry: quizHistory[sender.tag], noteTitle: noteTitle)
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func saveTapped() {
        guard let note else { return }
        note.isFavorite.toggle()
        DataStore.shared.save()
        updateSaveButton(note.isFavorite)
        showToast(note.isFavorite ? "저장됨 · 즐겨찾기에 추가했어요" : "즐겨찾기에서 해제했어요")
    }

    private func updateSaveButton(_ saved: Bool) {
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        saveButton.setTitle(saved ? " 저장됨" : " 저장", for: .normal)
        saveButton.setImage(UIImage(systemName: saved ? "bookmark.fill" : "bookmark",
                                    withConfiguration: cfg), for: .normal)
    }

    @objc private func keywordChipTapped(_ sender: UIButton) {
        selectedKeywordIndex = sender.tag
        refreshChipStyles()
        keywordDetailCard.configure(item: keywordItems[selectedKeywordIndex])
        view.setNeedsLayout()
        view.layoutIfNeeded()
        updateKeywordPointer()
    }

}

// MARK: - Tab Segment

final class SummaryTabSegment: UIView {

    private let stack = UIStackView()
    private var buttons: [UIButton] = []
    private(set) var selectedIndex: Int = 0
    var onChange: ((Int) -> Void)?

    init(titles: [String]) {
        super.init(frame: .zero)
        backgroundColor = UIColor.white.withAlphaComponent(0.55)
        layer.cornerRadius = 22

        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])

        for (i, title) in titles.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            b.layer.cornerRadius = 18
            b.tag = i
            b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            buttons.append(b)
            stack.addArrangedSubview(b)
        }
        applyStyles()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped(_ sender: UIButton) {
        guard sender.tag != selectedIndex else { return }
        selectedIndex = sender.tag
        applyStyles()
        onChange?(selectedIndex)
    }

    func setSelected(_ index: Int) {
        guard index >= 0, index < buttons.count, index != selectedIndex else { return }
        selectedIndex = index
        applyStyles()
    }

    private func applyStyles() {
        for (i, b) in buttons.enumerated() {
            if i == selectedIndex {
                b.backgroundColor = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)
                b.setTitleColor(.white, for: .normal)
            } else {
                b.backgroundColor = .clear
                b.setTitleColor(.darkGray, for: .normal)
            }
        }
    }
}

// MARK: - Summary Card

final class SummaryCardView: UIView {

    var onDetailTapped: (() -> Void)?

    init(item: SummaryItem) {
        super.init(frame: .zero)
        backgroundColor = .white
        layer.cornerRadius = 18
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 8
        translatesAutoresizingMaskIntoConstraints = false

        let iconCircle = UIView()
        iconCircle.backgroundColor = item.iconBackground
        iconCircle.layer.cornerRadius = 22
        iconCircle.translatesAutoresizingMaskIntoConstraints = false

        let romanLabel = UILabel()
        romanLabel.text = item.roman
        romanLabel.font = UIFont(name: "Georgia-Italic", size: 17) ?? UIFont.italicSystemFont(ofSize: 17)
        romanLabel.textColor = item.accentColor
        romanLabel.translatesAutoresizingMaskIntoConstraints = false

        let numberLabel = UILabel()
        numberLabel.text = "핵심 \(item.number)"
        numberLabel.font = UIFont.systemFont(ofSize: 12, weight: .bold)
        numberLabel.textColor = item.accentColor
        numberLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = item.title
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailLabel = UILabel()
        detailLabel.text = item.detail
        detailLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        detailLabel.textColor = UIColor(white: 0.35, alpha: 1.0)
        detailLabel.numberOfLines = 0
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        let detailButton = UIButton(type: .system)
        detailButton.setTitle("자세히 보기 →", for: .normal)
        detailButton.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        detailButton.setTitleColor(item.accentColor, for: .normal)
        detailButton.contentHorizontalAlignment = .leading
        detailButton.translatesAutoresizingMaskIntoConstraints = false
        detailButton.addAction(UIAction { [weak self] _ in
            self?.onDetailTapped?()
        }, for: .touchUpInside)

        addSubview(iconCircle)
        iconCircle.addSubview(romanLabel)
        addSubview(numberLabel)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(detailButton)

        NSLayoutConstraint.activate([
            iconCircle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconCircle.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            iconCircle.widthAnchor.constraint(equalToConstant: 44),
            iconCircle.heightAnchor.constraint(equalToConstant: 44),

            romanLabel.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            romanLabel.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            numberLabel.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            numberLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 14),

            titleLabel.topAnchor.constraint(equalTo: numberLabel.bottomAnchor, constant: 2),
            titleLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 14),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            detailLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 14),
            detailLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),

            detailButton.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 10),
            detailButton.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 14),
            detailButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Flow Layout

final class FlowLayoutView: UIView {

    var horizontalSpacing: CGFloat = 8
    var verticalSpacing: CGFloat = 10

    private var lastWidth: CGFloat = 0
    private var lastHeight: CGFloat = 0
    private var heightConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        let hc = heightAnchor.constraint(equalToConstant: 0)
        hc.priority = .defaultHigh
        hc.isActive = true
        heightConstraint = hc
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        guard w > 0 else { return }
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for sub in subviews {
            let size = sub.intrinsicContentSize
            if x > 0 && x + size.width > w {
                x = 0
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            sub.frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
        let total = y + rowHeight
        if total != lastHeight || w != lastWidth {
            lastHeight = total
            lastWidth = w
            heightConstraint?.constant = total
        }
    }
}

// MARK: - Keyword Chip

final class KeywordChipButton: UIButton {

    enum Style { case normal, primary, primarySelected, selected }

    var styleType: Style = .normal { didSet { applyStyle() } }

    private let primaryDark = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)
    private let selectedPurple = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentEdgeInsets = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        layer.cornerRadius = 19
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.04
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 4
        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func applyStyle() {
        switch styleType {
        case .normal:
            backgroundColor = .white
            setTitleColor(.black, for: .normal)
        case .primary, .primarySelected:
            backgroundColor = primaryDark
            setTitleColor(.white, for: .normal)
        case .selected:
            backgroundColor = selectedPurple
            setTitleColor(.white, for: .normal)
        }
    }
}

// MARK: - Keyword Detail Card

final class KeywordDetailCard: UIView {

    private let pointer = TrianglePointer()
    private var pointerCenterXConstraint: NSLayoutConstraint?

    private let card: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 18
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.06
        v.layer.shadowOffset = CGSize(width: 0, height: 4)
        v.layer.shadowRadius = 10
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let prefixLabel: UILabel = {
        let l = UILabel()
        l.text = "키워드"
        l.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        l.textColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        l.textColor = .black
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let frequencyBadge: PaddedLabel = {
        let l = PaddedLabel()
        l.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        l.textColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        l.backgroundColor = UIColor(red: 0.92, green: 0.88, blue: 0.97, alpha: 1.0)
        l.padding = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
        l.layer.cornerRadius = 12
        l.layer.masksToBounds = true
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let descriptionLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        l.textColor = UIColor(white: 0.30, alpha: 1.0)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let relatedTitle: UILabel = {
        let l = UILabel()
        l.text = "함께 보기"
        l.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        l.textColor = .gray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let relatedFlow: FlowLayoutView = {
        let v = FlowLayoutView()
        v.horizontalSpacing = 6
        v.verticalSpacing = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        addSubview(pointer)
        pointer.translatesAutoresizingMaskIntoConstraints = false

        addSubview(card)
        card.addSubview(prefixLabel)
        card.addSubview(titleLabel)
        card.addSubview(frequencyBadge)
        card.addSubview(descriptionLabel)
        card.addSubview(relatedTitle)
        card.addSubview(relatedFlow)

        let pointerCenterX = pointer.centerXAnchor.constraint(equalTo: leadingAnchor, constant: 80)
        pointerCenterX.isActive = true
        pointerCenterXConstraint = pointerCenterX

        NSLayoutConstraint.activate([
            pointer.topAnchor.constraint(equalTo: topAnchor),
            pointer.widthAnchor.constraint(equalToConstant: 20),
            pointer.heightAnchor.constraint(equalToConstant: 10),

            card.topAnchor.constraint(equalTo: pointer.bottomAnchor, constant: -1),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor),

            prefixLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            prefixLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            titleLabel.centerYAnchor.constraint(equalTo: prefixLabel.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: prefixLabel.trailingAnchor, constant: 10),

            frequencyBadge.centerYAnchor.constraint(equalTo: prefixLabel.centerYAnchor),
            frequencyBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            descriptionLabel.topAnchor.constraint(equalTo: prefixLabel.bottomAnchor, constant: 12),
            descriptionLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            descriptionLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            relatedTitle.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 14),
            relatedTitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            relatedFlow.topAnchor.constraint(equalTo: relatedTitle.bottomAnchor, constant: 8),
            relatedFlow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            relatedFlow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            relatedFlow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(item: KeywordItem) {
        titleLabel.text = item.title
        frequencyBadge.text = "\(item.frequency)회 등장"
        descriptionLabel.text = item.description
        relatedFlow.subviews.forEach { $0.removeFromSuperview() }
        for tag in item.related {
            let pill = PaddedLabel()
            pill.text = tag
            pill.font = UIFont.systemFont(ofSize: 12, weight: .medium)
            pill.textColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
            pill.backgroundColor = UIColor(red: 0.93, green: 0.88, blue: 0.97, alpha: 1.0)
            pill.padding = UIEdgeInsets(top: 5, left: 12, bottom: 5, right: 12)
            pill.layer.cornerRadius = 13
            pill.layer.masksToBounds = true
            relatedFlow.addSubview(pill)
        }
        relatedFlow.setNeedsLayout()
    }

    func setPointerCenterX(_ x: CGFloat) {
        let clamped = max(20, min(x, bounds.width - 20))
        pointerCenterXConstraint?.constant = clamped
    }
}

// MARK: - Dashed Border View

final class DashedBorderView: UIView {
    private let dashedLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        dashedLayer.fillColor = nil
        layer.addSublayer(dashedLayer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(strokeColor: UIColor, lineWidth: CGFloat,
                   dashPattern: [NSNumber], cornerRadius: CGFloat) {
        dashedLayer.strokeColor = strokeColor.cgColor
        dashedLayer.lineWidth = lineWidth
        dashedLayer.lineDashPattern = dashPattern
        layer.cornerRadius = cornerRadius
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        dashedLayer.frame = bounds
        dashedLayer.path = UIBezierPath(roundedRect: bounds,
                                        cornerRadius: layer.cornerRadius).cgPath
    }
}

// MARK: - Quiz Option

final class QuizOptionView: UIControl {

    enum DisplayState { case normal, selected, correct, incorrect }

    var displayState: DisplayState = .normal { didSet { applyStyle() } }

    private let numberCircle: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 11
        v.layer.borderWidth = 1
        v.isUserInteractionEnabled = false
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let numberLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let textLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let trailingIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .center
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    init(number: Int, text: String) {
        super.init(frame: .zero)
        layer.cornerRadius = 14
        translatesAutoresizingMaskIntoConstraints = false

        numberLabel.text = "\(number)"
        textLabel.text = text

        addSubview(numberCircle)
        numberCircle.addSubview(numberLabel)
        addSubview(textLabel)
        addSubview(trailingIcon)

        NSLayoutConstraint.activate([
            numberCircle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            numberCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            numberCircle.widthAnchor.constraint(equalToConstant: 22),
            numberCircle.heightAnchor.constraint(equalToConstant: 22),

            numberLabel.centerXAnchor.constraint(equalTo: numberCircle.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: numberCircle.centerYAnchor),

            textLabel.leadingAnchor.constraint(equalTo: numberCircle.trailingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: trailingIcon.leadingAnchor, constant: -8),
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            trailingIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            trailingIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            trailingIcon.widthAnchor.constraint(equalToConstant: 22),
            trailingIcon.heightAnchor.constraint(equalToConstant: 22),
        ])

        applyStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.75 : 1.0
        }
    }

    private func applyStyle() {
        let purple = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        let green = UIColor(red: 0.34, green: 0.62, blue: 0.40, alpha: 1.0)
        let red = UIColor(red: 0.82, green: 0.45, blue: 0.40, alpha: 1.0)
        let neutralBorder = UIColor(white: 0.72, alpha: 1.0)

        switch displayState {
        case .normal:
            backgroundColor = UIColor(white: 0.97, alpha: 1.0)
            layer.borderWidth = 0
            numberCircle.backgroundColor = .clear
            numberCircle.layer.borderColor = neutralBorder.cgColor
            numberLabel.textColor = UIColor(white: 0.4, alpha: 1.0)
            textLabel.textColor = UIColor(white: 0.20, alpha: 1.0)
            trailingIcon.isHidden = true
        case .selected:
            backgroundColor = UIColor(red: 0.95, green: 0.92, blue: 0.98, alpha: 1.0)
            layer.borderWidth = 2
            layer.borderColor = purple.cgColor
            numberCircle.backgroundColor = .clear
            numberCircle.layer.borderColor = purple.cgColor
            numberLabel.textColor = purple
            textLabel.textColor = .black
            trailingIcon.isHidden = true
        case .correct:
            backgroundColor = UIColor(red: 0.86, green: 0.94, blue: 0.85, alpha: 1.0)
            layer.borderWidth = 2
            layer.borderColor = green.cgColor
            numberCircle.backgroundColor = .clear
            numberCircle.layer.borderColor = green.cgColor
            numberLabel.textColor = green
            textLabel.textColor = .black
            trailingIcon.isHidden = false
            trailingIcon.image = UIImage(systemName: "checkmark.circle.fill",
                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            trailingIcon.tintColor = green
        case .incorrect:
            backgroundColor = UIColor(red: 0.98, green: 0.91, blue: 0.89, alpha: 1.0)
            layer.borderWidth = 2
            layer.borderColor = red.cgColor
            numberCircle.backgroundColor = .clear
            numberCircle.layer.borderColor = red.cgColor
            numberLabel.textColor = red
            textLabel.textColor = .black
            trailingIcon.isHidden = false
            trailingIcon.image = UIImage(systemName: "xmark.circle.fill",
                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .semibold))
            trailingIcon.tintColor = red
        }
    }
}

// MARK: - Triangle Pointer

final class TrianglePointer: UIView {
    private let shape = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        shape.fillColor = UIColor.white.cgColor
        layer.addSublayer(shape)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        let p = UIBezierPath()
        p.move(to: CGPoint(x: bounds.midX, y: 0))
        p.addLine(to: CGPoint(x: 0, y: bounds.maxY))
        p.addLine(to: CGPoint(x: bounds.maxX, y: bounds.maxY))
        p.close()
        shape.path = p.cgPath
        shape.frame = bounds
    }
}
