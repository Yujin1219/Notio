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

    private let mascotImageView: UIImageView = {
        let imageView = UIImageView(image: UIImage(named: "nio-hi"))
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "Notio"
        label.font = UIFont.systemFont(ofSize: 44, weight: .heavy)
        label.textColor = UIColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 1.0)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4
        label.attributedText = NSAttributedString(
            string: "강의 자료를 똑똑한 노트로,\nAI와 함께하는 스마트 학습",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(red: 0.43, green: 0.39, blue: 0.48, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
        )
        label.numberOfLines = 0
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)

        let stack = UIStackView(arrangedSubviews: [mascotImageView, logoLabel, descriptionLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.setCustomSpacing(28, after: mascotImageView)
        stack.setCustomSpacing(12, after: logoLabel)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            mascotImageView.widthAnchor.constraint(equalToConstant: 220),
            mascotImageView.heightAnchor.constraint(equalToConstant: 220),
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.routeNext()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func routeNext() {
        // 이미 로그인돼 있으면 홈으로, 아니면 온보딩 → 로그인 흐름으로.
        if SessionManager.isLoggedIn {
            setWindowRoot(AppNavigationController(rootViewController: HomeViewController()))
        } else {
            setWindowRoot(OnboardingViewController())
        }
    }
}
