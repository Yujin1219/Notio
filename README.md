# 📚 Notio

> 강의 노트(PDF)를 올리면 AI가 핵심 요약과 예상 문제를 만들어주는 학습 도우미 iOS 앱

마스코트 **Nio**와 함께, "올리기만 하면" 요약 · 퀴즈 · 오답 관리까지 한 번에 끝내고 능동적인 복습 사이클을 자동화합니다.

---

## 🎯 서비스 소개

- **무엇을** — PDF 강의 자료를 업로드하면 Gemini AI가 텍스트를 분석해 **핵심 요약 · 키워드 · 예상 문제**를 자동 생성합니다.
- **왜** — 방대한 강의 자료를 직접 요약·정리하고 문제를 만들어 복습하는 데 드는 시간과 노력을 줄이기 위해.
- **누구를 위해** — 강의 노트로 공부하는 **대학생 · 수험생**.
- **핵심 가치** — 요약 → 퀴즈 풀이 → 오답 복습으로 이어지는 **능동적 학습 루프**를 앱 하나로 자동화.

---

## ✨ 주요 기능

### 계정
- 이메일 · 비밀번호 **로컬 회원가입/로그인**, 유효성 검사 + 이메일 중복 확인
- 비밀번호 **SHA-256 해시** 저장, 약관 동의 UI
- **유저별 데이터 완전 분리** (내 노트만 조회)

### 노트 생성 (AI 분석)
- PDF 업로드 → **PDFKit 텍스트 추출** → Gemini 분석
- 자동 생성: 노트 제목 · 핵심 개념 요약 · 키워드
- 분석 진행 단계 표시 + **도중 취소** 가능

### 요약 (구조화)
- 개념별 요약 카드 + 상세 페이지(**정의 / 핵심 포인트 목록 / 비교 표**)
- 핵심 키워드 · 관련 용어 정리
- 업로드 **원문 텍스트** 열람

### 퀴즈 (온디맨드 생성)
- **난이도(상·중·하)** 와 **문제 수**를 직접 선택
- 난이도에 따라 AI가 실제로 다른 수준으로 출제
- **객관식(4지선다) + 주관식(단답형)** 혼합, 주관식은 유연한 채점
- 정답 텍스트 역매칭으로 정답 인덱스 보정, "이미 낸 문제 회피"로 매번 새로운 문제

### 복습 관리
- 퀴즈 응시 **기록 · 통계**(정답률 · 푼 문제 · 오답 수)
- 응시 내역 조회 + **문항별 내 답/정답 상세**
- **오답노트** 자동 수집 → 틀린 문제만 **다시 풀기**

### 학습 동기 부여
- 노트별 **학습률 · 상태**(진행중/완료)가 퀴즈 성취도에 따라 자동 갱신
- **연속 학습일(스트릭)** 과 이번 주 학습량

### 편의
- 노트 **검색**(제목·키워드), **카테고리 필터**(전공·교양·자격증), **즐겨찾기**
- **토스트** 알림, 빈 상태 안내, 로딩 인디케이터, 가장자리 스와이프 뒤로가기

---

## 🛠 기술 스택

| 영역 | 사용 기술 |
|---|---|
| 플랫폼 | iOS (Deployment Target 26.x) |
| 언어 / UI | Swift, **UIKit** (프로그래매틱 Auto Layout) |
| 데이터 영속 | **SwiftData** (유저 · 노트 · 퀴즈 기록 저장) |
| AI | **Google Gemini API** (`gemini-2.5-flash-lite`, 구조화 JSON 출력) |
| 네트워킹 | `URLSession` + **async/await**, 지수 백오프 자동 재시도 |
| 텍스트 추출 | **PDFKit** |
| 보안 | **CryptoKit** (비밀번호 SHA-256 해시) |

---

## 🧱 아키텍처 & 코드 구조

UIKit 기반의 **MVC + 서비스 레이어** 구조입니다. 화면 계층 이동은 `UINavigationController`(push/pop), 플로우 경계(스플래시→온보딩→로그인→홈)는 윈도우 루트 교체로 처리해 이전 화면을 메모리에서 해제합니다.

```
앱 시작
  Splash ─(root 교체)→ Onboarding ─(root 교체)→ Login ─(인증)→ AppNavigationController(Home)
                                                              │  push/pop
                                                              ▼
  Home → NewNote(시트) → AnalysisProgress(AI 분석) → Summary
  Home → Summary → { 원문 / 오답노트 / 다시풀기 / 퀴즈 기록 상세 / 새 문제 만들기 }
```

### 레이어별 핵심 파일

**모델 · 데이터**
- `NotioModels.swift` — SwiftData `@Model`: `User`, `Note`. 퀴즈 응시 기록(`QuizAttempt`/`AttemptAnswer`), 주관식 채점기(`AnswerMatcher`)
- `DataStore.swift` — `ModelContainer` 관리, CRUD, 첫 실행 **시드 데이터**, 학습률·스트릭 계산
- `SessionManager.swift` — 로그인 세션(UserDefaults) + 비밀번호 해시 + 입력 검증(`Validator`)

**AI 서비스**
- `GeminiService.swift` — Gemini REST 호출. 구조화 출력(`responseSchema`), 프롬프트, 자동 재시도, thinking/토큰 설정. `GeneratedContent`(요약·키워드·퀴즈) 모델
- `Secrets.swift` — API 키 보관 (**.gitignore 처리**)

**화면 (ViewController)**
- 인증: `SplashViewController`, `OnboardingViewController`, `LoginViewController`, `SignupViewController`, `AuthComponents.swift`
- 홈: `HomeViewController`, `NoteCardCell`, `StreakView`
- 생성: `NewNoteViewController`, `AnalysisProgressViewController`
- 학습: `SummaryViewController`, `SummaryDetailViewController`, `SourceTextViewController`
- 퀴즈: `NewQuizConfigViewController`, `QuizHistoryDetailViewController`, `WrongAnswerNotebookViewController`, `RetryQuizViewController`

**공통**
- `AppNavigation.swift` — `AppNavigationController`(바 숨김 + 스와이프 유지), `goBack()`, `setWindowRoot()`, 토스트

---

## 🔍 핵심 구현 설명

### 1) Gemini로 PDF → 구조화 학습 콘텐츠
Gemini는 멀티모달이라 PDF를 직접 읽을 수 있지만, 토큰 절감을 위해 **PDFKit 추출 텍스트를 우선** 전송하고 텍스트가 빈약하면(스캔본) PDF 원본을 base64로 보냅니다. `generationConfig.responseSchema`로 **JSON 스키마를 강제**해 파싱을 안정화합니다.

```swift
// 요약은 추론 off(출력이 커서 잘림 방지), 퀴즈는 추론 on(정답 정확도)
"generationConfig": [
    "responseMimeType": "application/json",
    "responseSchema": schema,
    "maxOutputTokens": 16384,
    "thinkingConfig": ["thinkingBudget": thinkingBudget]
]
```

- **자동 재시도**: 503(서버 과부하)·429·5xx·네트워크 오류는 지수 백오프로 재시도
- **잘림 감지**: `finishReason == "MAX_TOKENS"`이면 깨진 JSON 대신 명확히 안내
- **정답 보정**: 모델이 `correctIndex`를 틀려도, 정답 텍스트(`answer`)로 보기를 역매칭해 올바른 인덱스를 찾음

### 2) SwiftData 영속 + 유저별 분리
UIKit이라 SwiftUI의 `@Query` 자동 갱신이 없어, `ModelContext`로 직접 조회 후 화면을 수동 reload합니다. 모든 조회는 현재 로그인 유저(`ownerEmail`)로 필터링해 데이터를 분리합니다.

```swift
func fetchNotes() -> [Note] {
    let owner = SessionManager.currentEmail ?? ""
    let descriptor = FetchDescriptor<Note>(
        predicate: #Predicate { $0.ownerEmail == owner },
        sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    return (try? context.fetch(descriptor)) ?? []
}
```

생성된 콘텐츠·응시 기록은 `Note`에 JSON 문자열로 저장(`contentJSON`/`attemptsJSON`)해 유연하게 다룹니다.

### 3) 퀴즈 풀이 → 기록 → 학습률
퀴즈를 풀면 문항별 응답을 `QuizAttempt`로 저장하고, 그때마다 **최고 정답률을 학습률**로, 80% 이상이면 **완료 상태**로 갱신합니다. 오답노트·통계·스트릭은 모두 이 응시 기록에서 파생됩니다.

---

## ▶️ 실행 방법

1. `Notio.xcodeproj`를 Xcode로 엽니다.
2. **Gemini API 키 설정** — [Google AI Studio](https://aistudio.google.com)에서 무료 키 발급 후 `Notio/Secrets.swift`에 입력:
   ```swift
   enum Secrets {
       static let geminiAPIKey = "여기에_키_입력"
   }
   ```
   > `Secrets.swift`는 `.gitignore`에 등록되어 커밋되지 않습니다.
3. 시뮬레이터(또는 기기)에서 빌드 · 실행합니다.

### 데모 계정
첫 실행 시 샘플 데이터가 자동 시드됩니다.
- **이메일** `study@notio.io` / **비밀번호** `password`
- 로그인 화면의 **"둘러보기"** 로도 바로 탐색 가능
- 운영체제 · 데이터베이스 · 네트워크 노트에 요약 · 퀴즈 · 응시 기록 · 오답노트가 채워져 있습니다.

> ⚠️ 시드는 **첫 실행(계정이 없을 때)에만** 동작합니다. 데이터를 초기화하려면 시뮬레이터에서 앱을 삭제 후 재실행하세요.

---

## 📁 폴더 구조

```
Notio/
├── App/                AppDelegate, SceneDelegate
├── Models/             NotioModels, DataStore, SessionManager
├── Service/            GeminiService, Secrets
├── Common/             AppNavigation
├── 인증 화면           Splash / Onboarding / Login / Signup / AuthComponents
├── 홈                  Home / NoteCardCell / StreakView
├── 노트 생성           NewNote / AnalysisProgress
├── 학습                Summary / SummaryDetail / SourceText
└── 퀴즈                NewQuizConfig / QuizHistoryDetail / WrongAnswerNotebook / RetryQuiz
```
*(파일은 단일 `Notio/` 그룹에 위치하며, 위 분류는 역할 기준입니다.)*

---

<p align="center"><i>Made with 🦉 Nio</i></p>
