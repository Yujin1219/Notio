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

    private let pageIndicatorView: PillPageIndicatorView = {
        let v = PillPageIndicatorView(numberOfPages: 3)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
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
        setupSwipeGestures()
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        updatePage()
    }

    private func setupSwipeGestures() {
        let left = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        left.direction = .left
        view.addGestureRecognizer(left)

        let right = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        right.direction = .right
        view.addGestureRecognizer(right)
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
        view.addSubview(pageIndicatorView)
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

            // 페이지 인디케이터: 가운데 정렬
            pageIndicatorView.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -20),
            pageIndicatorView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

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
        pageIndicatorView.setCurrentPage(currentPage, animated: true)

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
            goToPage(currentPage + 1)
        } else {
            navigateToHome()
        }
    }

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        switch gesture.direction {
        case .left where currentPage < pages.count - 1:
            goToPage(currentPage + 1)
        case .right where currentPage > 0:
            goToPage(currentPage - 1)
        default:
            break
        }
    }

    private func goToPage(_ index: Int) {
        currentPage = index
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            self.updatePage()
        }
    }

    private func navigateToHome() {
        // 온보딩을 마치면 로그인 화면으로. (로그인/회원가입 후 홈으로 진입)
        setWindowRoot(AppNavigationController(rootViewController: LoginViewController()))
    }
}

// MARK: - Pill Page Indicator

final class PillPageIndicatorView: UIView {

    private let activeColor = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)
    private let inactiveColor = UIColor(red: 0.78, green: 0.76, blue: 0.78, alpha: 1.0)
    private let dotSize: CGFloat = 8
    private let activeWidth: CGFloat = 22

    private let stack = UIStackView()
    private var dots: [UIView] = []
    private var widthConstraints: [NSLayoutConstraint] = []

    init(numberOfPages: Int) {
        super.init(frame: .zero)
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        for _ in 0..<numberOfPages {
            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.backgroundColor = inactiveColor
            dot.layer.cornerRadius = dotSize / 2
            let widthC = dot.widthAnchor.constraint(equalToConstant: dotSize)
            widthC.isActive = true
            dot.heightAnchor.constraint(equalToConstant: dotSize).isActive = true
            widthConstraints.append(widthC)
            dots.append(dot)
            stack.addArrangedSubview(dot)
        }

        setCurrentPage(0, animated: false)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setCurrentPage(_ index: Int, animated: Bool) {
        for (i, dot) in dots.enumerated() {
            let isActive = (i == index)
            widthConstraints[i].constant = isActive ? activeWidth : dotSize
            let apply = {
                dot.backgroundColor = isActive ? self.activeColor : self.inactiveColor
                self.layoutIfNeeded()
            }
            if animated {
                UIView.animate(withDuration: 0.25,
                               delay: 0,
                               usingSpringWithDamping: 0.85,
                               initialSpringVelocity: 0,
                               options: [.curveEaseOut],
                               animations: apply)
            } else {
                apply()
            }
        }
    }
}
