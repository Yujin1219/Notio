//
//  SessionManager.swift
//  Notio
//
//  로컬 로그인 세션을 관리한다. 현재 로그인한 유저의 이메일을 UserDefaults에 저장하고,
//  실제 유저 레코드는 SwiftData에서 조회한다.
//

import Foundation
import CryptoKit

enum SessionManager {

    private static let key = "notio.currentUserEmail"

    /// 현재 로그인한 유저의 이메일. (없으면 비로그인 상태)
    static var currentEmail: String? {
        get { UserDefaults.standard.string(forKey: key) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    static var isLoggedIn: Bool { currentEmail != nil }

    static func login(email: String) { currentEmail = email }
    static func logout() { currentEmail = nil }

    /// 비밀번호를 SHA-256으로 해시한다. (로컬 데모용 — 평문 저장 방지)
    static func hash(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

/// 입력값 유효성 검사 유틸.
enum Validator {
    static func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }

    static func isValidPassword(_ password: String) -> Bool {
        return password.count >= 8
    }
}
