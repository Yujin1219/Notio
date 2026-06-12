//
//  GeminiService.swift
//  Notio
//
//  Gemini API로 강의 노트(PDF/텍스트)를 분석해 요약·키워드·퀴즈를 생성한다.
//  responseSchema로 구조화 출력을 강제해 파싱을 안정화한다.
//

import Foundation

// MARK: - 난이도

enum QuizDifficulty: String, CaseIterable, Codable {
    case easy = "하"
    case medium = "중"
    case hard = "상"

    /// Gemini에 전달할 난이도 지침.
    var guidance: String {
        switch self {
        case .easy:   return "쉬움 난이도: 핵심 개념과 정의를 그대로 확인하는 기본 문제. 함정 없이 직관적으로."
        case .medium: return "보통 난이도: 개념을 비교하거나 간단히 적용해야 풀리는 문제."
        case .hard:   return "어려움 난이도: 여러 개념을 응용하거나 함정·추론이 필요한 심화 문제."
        }
    }
}

// MARK: - 생성 결과 모델 (앱 전역에서 사용)

struct GeneratedContent: Codable {
    let title: String
    let summaries: [GeneratedSummary]
    let keywords: [GeneratedKeyword]
    let quizzes: [GeneratedQuiz]
}

struct GeneratedSummary: Codable {
    let title: String
    let detail: String
    let sections: [GeneratedSection]?   // 상세 페이지용 다중 섹션 (정의/목록/표)
}

struct GeneratedSection: Codable {
    let heading: String
    let type: String            // "definition" | "list" | "table"
    let text: String?           // definition 본문
    let bolded: [String]?       // definition에서 강조할 핵심 문구
    let items: [String]?        // list 항목
    let columns: [String]?      // table 헤더
    let rows: [[String]]?       // table 행
}

struct GeneratedKeyword: Codable {
    let title: String
    let description: String
    let related: [String]
}

struct GeneratedQuiz: Codable {
    let type: String?          // "multiple" | "short" (없으면 객관식으로 간주)
    let question: String
    let options: [String]?     // 객관식 보기
    let correctIndex: Int?     // 객관식 정답 인덱스
    let answer: String?        // 주관식 정답 텍스트
    let explanation: String
}

// MARK: - 에러

enum GeminiError: LocalizedError {
    case noAPIKey
    case invalidFile
    case http(Int, String)
    case overloaded(String)
    case emptyResponse(String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:    return "API 키가 설정되지 않았어요. Secrets.swift를 확인해주세요."
        case .invalidFile: return "파일에서 내용을 읽을 수 없어요."
        case .http(let code, let msg): return "요청 실패 (\(code))\n\n\(msg)"
        case .overloaded(let detail): return "서버 혼잡(503/429) · 자동 재시도 실패\n\n\(detail)"
        case .emptyResponse(let detail): return "응답이 비어 있어요\n\n\(detail)"
        case .decoding(let detail): return "응답 해석 실패\n\n\(detail)"
        }
    }
}

// MARK: - 서비스

final class GeminiService {

    static let shared = GeminiService()
    private init() {}

    private let model = "gemini-2.5-flash-lite"
    private let session = URLSession.shared

    /// 너무 큰 PDF는 inline 전송 한도를 넘으므로 텍스트 추출본을 보낸다.
    private let inlinePDFLimit = 15 * 1024 * 1024   // 약 15MB

    // MARK: 전체 분석 (요약 + 키워드 + 퀴즈)

    func generate(title: String?,
                  pdfData: Data?,
                  extractedText: String?,
                  includeQuizzes: Bool = false,
                  difficulty: QuizDifficulty = .medium,
                  quizCount: Int = 5) async throws -> GeneratedContent {
        let sourcePart = try makeSourcePart(pdfData: pdfData, extractedText: extractedText)
        let count = clampCount(quizCount)
        let parts: [[String: Any]] = [
            ["text": fullPrompt(title: title, includeQuizzes: includeQuizzes, difficulty: difficulty, count: count)],
            sourcePart
        ]
        // 문제를 포함하면 정확도를 위해 추론을 켜고, 요약만이면 잘림 방지를 위해 끈다.
        let inner = try await performRequest(parts: parts, schema: fullSchema,
                                             thinkingBudget: includeQuizzes ? -1 : 0)
        do { return try JSONDecoder().decode(GeneratedContent.self, from: inner) }
        catch {
            throw GeminiError.decoding("\(error)\n\n원문 응답:\n\(Self.preview(inner))")
        }
    }

    // MARK: 퀴즈만 재생성 (기존 노트의 요약·키워드를 근거로)

    func generateQuizzes(topic: String,
                         summaries: [GeneratedSummary],
                         keywords: [GeneratedKeyword],
                         difficulty: QuizDifficulty,
                         count: Int,
                         avoiding: [String] = []) async throws -> [GeneratedQuiz] {
        let n = clampCount(count)
        let parts: [[String: Any]] = [
            ["text": quizPrompt(topic: topic, summaries: summaries, keywords: keywords,
                                difficulty: difficulty, count: n, avoiding: avoiding)]
        ]
        // 정답 정확도(추론 ON) + 매번 다른 문제(높은 temperature).
        let inner = try await performRequest(parts: parts, schema: quizArraySchema,
                                             thinkingBudget: -1, temperature: 1.0)
        do { return try JSONDecoder().decode([GeneratedQuiz].self, from: inner) }
        catch {
            throw GeminiError.decoding("\(error)\n\n원문 응답:\n\(Self.preview(inner))")
        }
    }

    // MARK: - 요청 공통 처리

    private func performRequest(parts: [[String: Any]], schema: [String: Any],
                                thinkingBudget: Int = 0, temperature: Double = 0.4) async throws -> Data {
        let key = Secrets.geminiAPIKey
        guard !key.isEmpty, key != "YOUR_GEMINI_API_KEY" else { throw GeminiError.noAPIKey }

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": [
                "responseMimeType": "application/json",
                "responseSchema": schema,
                "temperature": temperature,
                "maxOutputTokens": 16384,        // 응답 잘림(JSON 깨짐) 방지
                // thinkingBudget: 0=끄기(요약처럼 출력 큰 작업), -1=동적(퀴즈처럼 추론 필요한 작업)
                "thinkingConfig": ["thinkingBudget": thinkingBudget]
            ]
        ]

        var request = URLRequest(url: endpoint())
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
        let httpBody = try JSONSerialization.data(withJSONObject: body)
        request.httpBody = httpBody
        request.timeoutInterval = 120
        Self.log("요청 시작 · model=\(model) · 요청크기=\(httpBody.count / 1024)KB")

        // 503(과부하)·429(레이트리밋)·5xx·네트워크 오류는 지수 백오프로 자동 재시도.
        let maxAttempts = 4
        var attempt = 0
        while true {
            attempt += 1
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw GeminiError.emptyResponse("HTTP 응답 형식이 올바르지 않아요.")
                }
                Self.log("응답 · 시도 \(attempt)/\(maxAttempts) · status=\(http.statusCode)")

                if (200..<300).contains(http.statusCode) {
                    let envelope = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    let candidate = envelope.candidates?.first
                    // 출력 토큰 한도로 응답이 잘린 경우 → 명확히 안내
                    if candidate?.finishReason == "MAX_TOKENS" {
                        throw GeminiError.decoding("응답이 너무 길어 잘렸어요. 다시 시도하거나 문제 수를 줄여보세요.")
                    }
                    guard let text = candidate?.content?.parts?.first?.text,
                          let inner = text.data(using: .utf8) else {
                        throw GeminiError.emptyResponse("status=\(http.statusCode)\n본문:\n\(Self.preview(data))")
                    }
                    return inner
                }

                Self.log("실패 status=\(http.statusCode) · 본문: \(Self.preview(data))")

                // 재시도 가능한 상태 코드면 잠시 대기 후 다시.
                if [429, 500, 502, 503, 504].contains(http.statusCode), attempt < maxAttempts {
                    try await backoffSleep(attempt: attempt)
                    continue
                }
                let detail = Self.extractErrorMessage(data) ?? Self.preview(data)
                if http.statusCode == 503 || http.statusCode == 429 {
                    throw GeminiError.overloaded(detail)
                }
                throw GeminiError.http(http.statusCode, detail)
            } catch let error as GeminiError {
                throw error   // 우리가 던진 에러는 그대로 전달 (재시도 안 함)
            } catch {
                // URLSession 네트워크 오류(타임아웃 등)는 몇 번 재시도.
                Self.log("네트워크 오류 · 시도 \(attempt)/\(maxAttempts) · \(error.localizedDescription)")
                if attempt < maxAttempts {
                    try await backoffSleep(attempt: attempt)
                    continue
                }
                throw error
            }
        }
    }

    // MARK: - 로깅

    private static func log(_ message: String) {
        print("🟣 [Gemini] \(message)")
    }

    /// 응답 본문을 일부만 잘라 보여준다. (알림이 너무 길어지지 않게)
    private static func preview(_ data: Data, limit: Int = 700) -> String {
        let s = String(data: data, encoding: .utf8) ?? "<비텍스트 \(data.count)바이트>"
        return s.count > limit ? String(s.prefix(limit)) + "…(생략)" : s
    }

    /// 지수 백오프 + 지터. (1차 ~1.2s, 2차 ~2.4s, 3차 ~4.8s)
    private func backoffSleep(attempt: Int) async throws {
        let base = 1.2 * pow(2.0, Double(attempt - 1))
        let jitter = Double.random(in: 0...0.5)
        try await Task.sleep(nanoseconds: UInt64((base + jitter) * 1_000_000_000))
    }

    /// 추출 텍스트가 충분하면 텍스트, 아니면(스캔본 등) PDF 원본을 파트로 만든다.
    private func makeSourcePart(pdfData: Data?, extractedText: String?) throws -> [String: Any] {
        let trimmed = (extractedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 50 {
            return ["text": "다음은 강의 노트 원문이에요:\n\n\(trimmed)"]
        } else if let pdfData, pdfData.count <= inlinePDFLimit {
            return ["inlineData": ["mimeType": "application/pdf", "data": pdfData.base64EncodedString()]]
        } else {
            throw GeminiError.invalidFile
        }
    }

    private func clampCount(_ n: Int) -> Int { min(max(n, 1), 20) }

    private func endpoint() -> URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
    }

    // MARK: - Prompts

    private func fullPrompt(title: String?, includeQuizzes: Bool, difficulty: QuizDifficulty, count: Int) -> String {
        let quizSection = includeQuizzes
            ? """
              4) quizzes: 문제 정확히 \(count)개. 난이도: \(difficulty.guidance)
                 객관식과 주관식(단답형)을 섞어서 내. (대략 객관식 60%, 주관식 40%)
                 - 객관식: type="multiple", options(보기 4개), correctIndex(0~3, 정답 보기 인덱스),
                   answer(정답 보기의 전체 텍스트 — options 배열 중 하나와 글자까지 정확히 동일해야 함).
                 - 주관식: type="short", answer(짧은 정답 단어나 구. 채점이 쉽도록 핵심 용어로).
                 - 공통: question, explanation(해설 1~2문장).
                 ★ 매우 중요: 객관식은 answer, correctIndex, explanation이 모두 같은 보기(정답)를 가리켜야 한다.
                   먼저 문제의 정답을 정하고, 그 정답을 answer에 적고, options에서 그 위치를 correctIndex로,
                   해설은 그 정답을 설명하도록 해. 셋이 어긋나면 안 된다.
              """
            : "4) quizzes: 빈 배열 []로 둬. 문제는 만들지 마."
        return """
        너는 학생의 강의 노트를 분석해 학습을 돕는 한국어 AI야.
        주어진 강의 노트 내용을 바탕으로 아래를 생성해줘. 모든 텍스트는 한국어로 작성해.

        1) title: 노트에 어울리는 짧은 제목(\(title.map { "참고 제목: \($0)" } ?? "내용 기반으로 직접 정해줘")).
        2) summaries: 핵심 개념 요약 3~5개. 각 항목은 다음을 포함해.
           - title: 짧은 개념명
           - detail: 1~2문장 핵심 설명
           - sections: 그 개념을 정리한 2~3개의 섹션 배열. 형식을 섞어서 간결하게.
             각 섹션은 heading(소제목)과 type을 갖고, type에 따라 내용을 채워:
             · type="definition": text(정의·설명 2~3문장), bolded(text 안에서 강조할 핵심 문구 1~3개, text에 그대로 들어있는 부분 문자열).
             · type="list": items(핵심 포인트 3~4개).
             · type="table": columns(열 제목 2~3개), rows(각 행은 columns 수와 같은 칸, 3~4행). 비교에 꼭 필요할 때만.
             definition 1개 + list 1개를 기본으로, 비교가 필요하면 table 1개까지만 추가해.
        3) keywords: 중요 키워드 4~8개. 각 항목은 title, description(한 문장), related(관련 용어 2~4개).
        \(quizSection)

        반드시 제공된 스키마(JSON) 형식만 출력해. 노트에 없는 내용은 지어내지 말고 핵심에 집중해.
        """
    }

    private func quizPrompt(topic: String, summaries: [GeneratedSummary],
                            keywords: [GeneratedKeyword], difficulty: QuizDifficulty,
                            count: Int, avoiding: [String]) -> String {
        var context = "주제: \(topic)\n"
        if !summaries.isEmpty {
            context += "\n[핵심 요약]\n" + summaries.map { "- \($0.title): \($0.detail)" }.joined(separator: "\n")
        }
        if !keywords.isEmpty {
            context += "\n\n[키워드]\n" + keywords.map { "- \($0.title): \($0.description)" }.joined(separator: "\n")
        }
        var avoidBlock = ""
        if !avoiding.isEmpty {
            avoidBlock = "\n\n[이미 출제된 문제 — 이것들과 주제·표현이 겹치지 않게 완전히 새로운 문제를 내]\n"
                + avoiding.prefix(30).map { "- \($0)" }.joined(separator: "\n")
        }
        return """
        아래 학습 내용을 바탕으로 문제를 정확히 \(count)개 만들어줘. 모두 한국어로.
        난이도: \(difficulty.guidance)
        객관식과 주관식(단답형)을 섞어서 내. (대략 객관식 60%, 주관식 40%)
        - 객관식: type="multiple", options(보기 4개), correctIndex(0~3, 정답 인덱스),
          answer(정답 보기의 전체 텍스트 — options 중 하나와 글자까지 정확히 동일).
        - 주관식: type="short", answer(짧은 정답 단어나 구. 핵심 용어로).
        - 공통: question, explanation(해설 1~2문장).
        ★ 매우 중요: 객관식은 answer, correctIndex, explanation이 모두 같은 보기(정답)를 가리켜야 한다.
          먼저 정답을 정하고 → answer에 적고 → options에서 그 위치를 correctIndex로 → 해설은 그 정답을 설명. 셋이 어긋나면 안 된다.
        다양한 개념·관점에서 매번 새로운 문제를 내고, 서로 중복되지 않게 해.

        \(context)\(avoidBlock)

        반드시 제공된 스키마(JSON 배열) 형식만 출력해.
        """
    }

    // MARK: - Schemas

    private func strType() -> [String: Any] { ["type": "STRING"] }

    private var quizItemSchema: [String: Any] {
        [
            "type": "OBJECT",
            "properties": [
                "type": ["type": "STRING", "enum": ["multiple", "short"]],
                "question": strType(),
                "options": ["type": "ARRAY", "items": strType()],
                "correctIndex": ["type": "INTEGER"],
                "answer": strType(),
                "explanation": strType()
            ],
            "required": ["type", "question", "explanation"]
        ]
    }

    private var quizArraySchema: [String: Any] {
        ["type": "ARRAY", "items": quizItemSchema]
    }

    private var fullSchema: [String: Any] {
        [
            "type": "OBJECT",
            "properties": [
                "title": strType(),
                "summaries": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "title": strType(),
                            "detail": strType(),
                            "sections": [
                                "type": "ARRAY",
                                "items": [
                                    "type": "OBJECT",
                                    "properties": [
                                        "heading": strType(),
                                        "type": ["type": "STRING", "enum": ["definition", "list", "table"]],
                                        "text": strType(),
                                        "bolded": ["type": "ARRAY", "items": strType()],
                                        "items": ["type": "ARRAY", "items": strType()],
                                        "columns": ["type": "ARRAY", "items": strType()],
                                        "rows": ["type": "ARRAY", "items": ["type": "ARRAY", "items": strType()]]
                                    ],
                                    "required": ["heading", "type"]
                                ]
                            ]
                        ],
                        "required": ["title", "detail", "sections"]
                    ]
                ],
                "keywords": [
                    "type": "ARRAY",
                    "items": [
                        "type": "OBJECT",
                        "properties": [
                            "title": strType(),
                            "description": strType(),
                            "related": ["type": "ARRAY", "items": strType()]
                        ],
                        "required": ["title", "description", "related"]
                    ]
                ],
                "quizzes": quizArraySchema
            ],
            "required": ["title", "summaries", "keywords", "quizzes"]
        ]
    }

    private static func extractErrorMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = obj["error"] as? [String: Any],
              let message = error["message"] as? String else { return nil }
        return message
    }
}

// MARK: - 응답 봉투 (디코딩용)

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]?
    struct Candidate: Decodable {
        let content: Content?
        let finishReason: String?
        struct Content: Decodable {
            let parts: [Part]?
            struct Part: Decodable { let text: String? }
        }
    }
}
