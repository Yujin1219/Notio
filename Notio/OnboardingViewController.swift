//
//  OnboardingViewController.swift
//  Notio
//

import UIKit

struct OnboardingPage {
    let imageName: String
    let stepLabel: String
    let title: String
    let features: [(icon: String, text: String)]
}

class OnboardingViewController: UIViewController {

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            imageName: "nio-hi",
            stepLabel: "01 / 03  UPLOAD",
            title: "PDF만 올리면 끝",
            features: [
                ("doc.fill", "파일 업로드만 하면 자동 분석"),
                ("globe", "한글·영어 모두 지원"),
                ("clock.fill", "언제 어디서든 간편하게"),
            ]
        ),
        OnboardingPage(
            imageName: "nio-think",
            stepLabel: "02 / 03  ANALYZE",
            title: "AI가 똑똑하게\n핵심을 추려요",
            features: [
                ("text.magnifyingglass", "핵심 키워드 자동 추출"),
                ("doc.text.fill", "요약 노트 자동 생성"),
                ("lightbulb.fill", "중요도 기반 정리"),
            ]
        ),
        OnboardingPage(
            imageName: "nio-happy",
            stepLabel: "03 / 03  QUIZ",
            title: "퀴즈로\n오래 기억하세요",
            features: [
                ("questionmark.circle.fill", "AI가 자동으로 퀴즈 생성"),
                ("brain.head.profile", "반복 학습으로 높은 기억 효과"),
                ("chart.bar.fill", "학습 진도와 성취도 추적"),
            ]
        ),
    ]

    private var currentPage = 0

    // MARK: - Gradient

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

    // MARK: - UI

    private let characterImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let stepLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textColor = UIColor.gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        label.textColor = .black
        label.numberOfLines = 0
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let featuresStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let pageControl: UIPageControl = {
        let pc = UIPageControl()
        pc.numberOfPages = 3
        pc.currentPage = 0
        pc.currentPageIndicatorTintColor = UIColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1.0)
        pc.pageIndicatorTintColor = UIColor(red: 0.78, green: 0.76, blue: 0.82, alpha: 1.0)
        pc.translatesAutoresizingMaskIntoConstraints = false
        pc.isUserInteractionEnabled = false
        return pc
    }()

    private let nextButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor(red: 0.20, green: 0.20, blue: 0.25, alpha: 1.0)
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        setupLayout()
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        updatePage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(characterImageView)
        view.addSubview(stepLabel)
        view.addSubview(titleLabel)
        view.addSubview(featuresStackView)
        view.addSubview(pageControl)
        view.addSubview(nextButton)

        NSLayoutConstraint.activate([
            // 캐릭터: 상단 중앙, 화면 상단에서 약간 아래
            characterImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 32),
            characterImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            characterImageView.widthAnchor.constraint(equalToConstant: 200),
            characterImageView.heightAnchor.constraint(equalToConstant: 200),

            // 스텝 라벨: 캐릭터 아래, 좌측 정렬
            stepLabel.topAnchor.constraint(equalTo: characterImageView.bottomAnchor, constant: 28),
            stepLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),

            // 제목: 스텝 라벨 아래, 좌측 정렬
            titleLabel.topAnchor.constraint(equalTo: stepLabel.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),

            // feature 리스트: 제목 아래, 좌측 정렬
            featuresStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            featuresStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 36),
            featuresStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -36),

            // 페이지 dots: 좌측 정렬
            pageControl.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -20),
            pageControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            // 버튼: 하단
            nextButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            nextButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: - Update

    private func updatePage() {
        let page = pages[currentPage]

        characterImageView.image = UIImage(named: page.imageName)
        stepLabel.text = page.stepLabel
        titleLabel.text = page.title
        pageControl.currentPage = currentPage

        // features 갱신
        featuresStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for feature in page.features {
            let row = makeFeatureRow(icon: feature.icon, text: feature.text)
            featuresStackView.addArrangedSubview(row)
        }

        if currentPage == pages.count - 1 {
            nextButton.setTitle("시작하기 →", for: .normal)
        } else {
            nextButton.setTitle("다음 →", for: .normal)
        }
    }

    private func makeFeatureRow(icon: String, text: String) -> UIView {
        let container = UIStackView()
        container.axis = .horizontal
        container.spacing = 12
        container.alignment = .center

        // 아이콘 원형 배경
        let iconBg = UIView()
        iconBg.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        iconBg.layer.cornerRadius = 18
        iconBg.translatesAutoresizingMaskIntoConstraints = false
        iconBg.widthAnchor.constraint(equalToConstant: 36).isActive = true
        iconBg.heightAnchor.constraint(equalToConstant: 36).isActive = true

        let iconView = UIImageView()
        let config = UIImage.SymbolConfiguration(pointSize: 15, weight: .medium)
        iconView.image = UIImage(systemName: icon, withConfiguration: config)
        iconView.tintColor = UIColor(red: 0.35, green: 0.30, blue: 0.50, alpha: 1.0)
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconBg.addSubview(iconView)

        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconBg.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconBg.centerYAnchor),
        ])

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = UIColor(red: 0.25, green: 0.25, blue: 0.28, alpha: 1.0)

        container.addArrangedSubview(iconBg)
        container.addArrangedSubview(label)

        return container
    }

    // MARK: - Actions

    @objc private func nextTapped() {
        if currentPage < pages.count - 1 {
            currentPage += 1
            UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
                self.updatePage()
            }
        } else {
            navigateToHome()
        }
    }

    private func navigateToHome() {
        let homeVC = HomeViewController()
        homeVC.modalPresentationStyle = .fullScreen
        homeVC.modalTransitionStyle = .crossDissolve
        present(homeVC, animated: true)
    }
}
