//
//  SplashViewController.swift
//  Notio
//

import UIKit

class SplashViewController: UIViewController {

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

    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "Notio"
        label.font = UIFont.systemFont(ofSize: 44, weight: .bold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.text = "강의 자료를 똑똑한 노트로,\nAI와 함께하는 스마트 학습"
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .darkGray
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)

        view.addSubview(logoLabel)
        view.addSubview(descriptionLabel)

        // 디자인: 로고가 화면 하단 1/3 지점, 왼쪽 정렬
        NSLayoutConstraint.activate([
            logoLabel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -view.bounds.height * 0.28),
            logoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),

            descriptionLabel.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 10),
            descriptionLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            descriptionLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.navigateToOnboarding()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func navigateToOnboarding() {
        let onboardingVC = OnboardingViewController()
        onboardingVC.modalPresentationStyle = .fullScreen
        onboardingVC.modalTransitionStyle = .crossDissolve
        present(onboardingVC, animated: true)
    }
}
