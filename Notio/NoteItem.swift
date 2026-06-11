//
//  NoteItem.swift
//  Notio
//

import Foundation

enum NoteStatus: String {
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

struct NoteItem {
    let title: String
    let keywords: String
    let status: NoteStatus
    let progress: Double // 0.0 ~ 1.0
}
