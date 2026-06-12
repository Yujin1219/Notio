//
//  NotioModels.swift
//  Notio
//
//  SwiftData 영속 모델. (1단계: 노트 목록)
//

import Foundation
import SwiftData

enum NoteStatus: String, Codable {
    case completed = "완료"
    case inProgress = "진행중"
}

enum NoteCategory: String, CaseIterable {
    case all = "전체"
    case major = "전공"
    case liberal = "교양"
    case certificate = "자격증"
    case bookmark = "즐겨찾기"
}

@Model
final class User {
    var nickname: String
    @Attribute(.unique) var email: String
    var passwordHash: String
    var createdAt: Date

    init(nickname: String, email: String, passwordHash: String, createdAt: Date = .now) {
        self.nickname = nickname
        self.email = email
        self.passwordHash = passwordHash
        self.createdAt = createdAt
    }
}

@Model
final class Note {
    var title: String
    var keywords: String
    var statusRaw: String
    var progress: Double      // 0.0 ~ 1.0
    var categoryRaw: String
    var createdAt: Date
    var ownerEmail: String    // 소유 유저 (유저별 분리)
    var contentJSON: String?  // Gemini가 생성한 요약·키워드·퀴즈 (GeneratedContent를 JSON 인코딩)
    var attemptsJSON: String? = nil  // 퀴즈 응시 기록 ([QuizAttempt]를 JSON 인코딩)
    var sourceText: String? = nil    // 파일에서 추출한 원문 텍스트
    var isFavorite: Bool = false     // 즐겨찾기(저장) 여부

    init(title: String,
         keywords: String,
         status: NoteStatus,
         progress: Double,
         category: NoteCategory = .major,
         ownerEmail: String = "",
         contentJSON: String? = nil,
         createdAt: Date = .now) {
        self.title = title
        self.keywords = keywords
        self.statusRaw = status.rawValue
        self.progress = progress
        self.categoryRaw = category.rawValue
        self.ownerEmail = ownerEmail
        self.contentJSON = contentJSON
        self.createdAt = createdAt
    }

    /// 저장된 JSON을 GeneratedContent로 디코딩한다. (없거나 깨졌으면 nil)
    var generatedContent: GeneratedContent? {
        guard let contentJSON, let data = contentJSON.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(GeneratedContent.self, from: data)
    }

    var status: NoteStatus {
        get { NoteStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    var category: NoteCategory {
        get { NoteCategory(rawValue: categoryRaw) ?? .major }
        set { categoryRaw = newValue.rawValue }
    }

    /// 저장된 퀴즈 응시 기록 (최신순으로 저장됨).
    var quizAttempts: [QuizAttempt] {
        guard let attemptsJSON, let data = attemptsJSON.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([QuizAttempt].self, from: data)) ?? []
    }
}

// MARK: - 퀴즈 응시 기록

struct QuizAttempt: Codable {
    var date: Date
    var durationSeconds: Int
    var answers: [AttemptAnswer]

    var total: Int { answers.count }
    var correct: Int { answers.filter { $0.isCorrect }.count }
    var percent: Int { total == 0 ? 0 : Int((Double(correct) / Double(total) * 100).rounded()) }
}

struct AttemptAnswer: Codable {
    var question: String
    var options: [String]
    var selectedIndex: Int
    var correctIndex: Int
    // 주관식(단답형)용 — 구버전 데이터 호환을 위해 모두 옵셔널.
    var isShort: Bool? = nil
    var typedAnswer: String? = nil
    var correctText: String? = nil
    var correctFlag: Bool? = nil      // 주관식 채점 결과

    var isCorrect: Bool {
        if isShort == true { return correctFlag ?? false }
        return selectedIndex == correctIndex
    }

    /// 화면 표시용 내 답.
    var displayMyAnswer: String {
        if isShort == true {
            let t = typedAnswer ?? ""
            return t.isEmpty ? "(미응답)" : t
        }
        return options.indices.contains(selectedIndex) ? options[selectedIndex] : "-"
    }

    /// 화면 표시용 정답.
    var displayCorrectAnswer: String {
        if isShort == true { return correctText ?? "-" }
        return options.indices.contains(correctIndex) ? options[correctIndex] : "-"
    }
}

/// 주관식 답안 채점. (공백·대소문자 무시 + 핵심 답 포함 인정)
enum AnswerMatcher {
    static func normalize(_ s: String) -> String {
        s.lowercased()
         .replacingOccurrences(of: " ", with: "")
         .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isCorrect(typed: String, correct: String) -> Bool {
        let t = normalize(typed), c = normalize(correct)
        guard !t.isEmpty, !c.isEmpty else { return false }
        if t == c { return true }
        // 정답 핵심어가 답안에 포함되면 인정 (예: "라운드로빈" ⊂ "라운드로빈방식")
        if c.count >= 2 && (t.contains(c) || c.contains(t)) { return true }
        return false
    }
}
