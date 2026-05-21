//
//  ViewController.swift
//  Notio
//
//  Created by Yujin on 5/21/26.
//

import UIKit

final class ViewController: UIViewController {

    private let gradientLayer = CAGradientLayer()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupBackground()
        setupContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func setupBackground() {
        gradientLayer.colors = [
            UIColor(red: 0.85, green: 0.82, blue: 0.88, alpha: 1.0).cgColor,
            UIColor(red: 0.95, green: 0.91, blue: 0.83, alpha: 1.0).cgColor
        ]
        gradientLayer.locations = [0.0, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        view.layer.insertSublayer(gradientLayer, at: 0)
    }

    private func setupContent() {
        let container = UIStackView()
        container.axis = .vertical
        container.alignment = .center
        container.spacing = 0
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)

        let mascotImageView = UIImageView(image: UIImage(named: "nio-hi"))
        mascotImageView.contentMode = .scaleAspectFit
        mascotImageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = "Notio"
        titleLabel.font = UIFont.systemFont(ofSize: 44, weight: .heavy)
        titleLabel.textColor = UIColor(red: 0.10, green: 0.09, blue: 0.14, alpha: 1.0)
        titleLabel.textAlignment = .center

        let subtitleLabel = UILabel()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 4
        subtitleLabel.attributedText = NSAttributedString(
            string: "강의 자료를 똑똑한 노트로,\nNio와 함께 시작해요",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: UIColor(red: 0.43, green: 0.39, blue: 0.48, alpha: 1.0),
                .paragraphStyle: paragraphStyle
            ]
        )
        subtitleLabel.numberOfLines = 0
        subtitleLabel.textAlignment = .center

        container.addArrangedSubview(mascotImageView)
        container.setCustomSpacing(28, after: mascotImageView)
        container.addArrangedSubview(titleLabel)
        container.setCustomSpacing(12, after: titleLabel)
        container.addArrangedSubview(subtitleLabel)

        let versionLabel = UILabel()
        versionLabel.text = "v 1.0.0 · © Notio"
        versionLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        versionLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
        versionLabel.textAlignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(versionLabel)

        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            container.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            mascotImageView.widthAnchor.constraint(equalToConstant: 220),
            mascotImageView.heightAnchor.constraint(equalToConstant: 220),

            versionLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            versionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }
}
