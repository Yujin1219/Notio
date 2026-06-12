//
//  AppNavigation.swift
//  Notio
//
//  앱 전역 내비게이션 헬퍼.
//  - 화면 계층 이동은 UINavigationController push/pop 으로 처리한다.
//  - 모든 화면은 자체 커스텀 상단 바(뒤로가기 chevron + 제목)를 쓰므로
//    시스템 내비게이션 바는 숨긴다. 대신 가장자리 스와이프 뒤로가기는 유지한다.
//

import UIKit

/// 시스템 내비게이션 바를 숨기면서도 가장자리 스와이프 뒤로가기를 살려두는 내비게이션 컨트롤러.
final class AppNavigationController: UINavigationController, UIGestureRecognizerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
        setNavigationBarHidden(true, animated: false)
        interactivePopGestureRecognizer?.delegate = self
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 루트 화면에서는 스와이프 뒤로가기를 막는다.
        return viewControllers.count > 1
    }
}

extension UIViewController {

    /// 화면을 닫는다. 내비게이션 스택에 push 된 화면이면 pop, 모달로 present 된
    /// 화면이면 dismiss 한다. 두 진입 경로(계층 이동 / 모달)를 모두 안전하게 처리한다.
    func goBack(animated: Bool = true) {
        if let nav = navigationController, nav.viewControllers.first !== self {
            nav.popViewController(animated: animated)
        } else {
            dismiss(animated: animated)
        }
    }

    /// 화면 하단에 잠깐 떴다 사라지는 토스트 메시지를 보여준다.
    func showToast(_ message: String, duration: TimeInterval = 1.8) {
        let label = PaddedLabel()
        label.text = message
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 0.12, alpha: 0.92)
        label.padding = UIEdgeInsets(top: 11, left: 18, bottom: 11, right: 18)
        label.layer.cornerRadius = 20
        label.layer.masksToBounds = true
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 28),
            label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -28),
        ])
        UIView.animate(withDuration: 0.25, animations: { label.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: []) {
                label.alpha = 0
            } completion: { _ in label.removeFromSuperview() }
        }
    }

    /// 윈도우의 루트 화면을 교체한다. (스플래시 → 온보딩 → 홈 같은 플로우 경계)
    /// 교체된 이전 화면 계층은 메모리에서 해제된다.
    func setWindowRoot(_ viewController: UIViewController) {
        guard let window = view.window else { return }
        window.rootViewController = viewController
        UIView.transition(with: window, duration: 0.3,
                          options: .transitionCrossDissolve,
                          animations: nil, completion: nil)
    }
}
