//
//  WrongAnswerNotebookViewController.swift
//  Notio
//

import UIKit

class WrongAnswerNotebookViewController: UIViewController {

    private let wrongAnswers: [WrongAnswer]

    init(wrongAnswers: [WrongAnswer]) {
        self.wrongAnswers = wrongAnswers
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - UI

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

    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        let cfg = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        b.setImage(UIImage(systemName: "chevron.left", withConfiguration: cfg), for: .normal)
        b.tintColor = .black
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let navTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "오답노트"
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .black
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let solveAllButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("다시 풀기", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        b.setTitleColor(UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0), for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 14
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        setupLayout()
        populateContent()

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        solveAllButton.addTarget(self, action: #selector(solveAllTapped), for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(backButton)
        view.addSubview(navTitleLabel)
        view.addSubview(solveAllButton)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            navTitleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            navTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            solveAllButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            solveAllButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),
        ])
    }

    private func populateContent() {
        guard !wrongAnswers.isEmpty else {
            // 오답이 없으면 "다시 풀기" 버튼을 숨기고 빈 상태만 보여준다.
            solveAllButton.isHidden = true
            contentStack.addArrangedSubview(makeEmptyCard())
            contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last!)
            contentStack.addArrangedSubview(makeNioCard())
            return
        }
        contentStack.addArrangedSubview(makeHeroCard())
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(makeFilterRow())
        contentStack.setCustomSpacing(10, after: contentStack.arrangedSubviews.last!)
        for item in wrongAnswers {
            contentStack.addArrangedSubview(makeWrongAnswerCard(item))
        }
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(makeNioCard())
    }

    private func makeEmptyCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(red: 0.99, green: 0.92, blue: 0.78, alpha: 0.5)
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = "아직 틀린 문제가 없어요"
        title.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        title.textColor = .black
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "퀴즈를 풀다 틀린 문제가 여기에 모여요"
        subtitle.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = UIColor(white: 0.35, alpha: 1.0)
        subtitle.numberOfLines = 0
        subtitle.textAlignment = .center
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(title)
        card.addSubview(subtitle)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: card.topAnchor, constant: 30),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            subtitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subtitle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            subtitle.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -30),
        ])
        return card
    }

    private func makeHeroCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor(red: 0.99, green: 0.92, blue: 0.78, alpha: 0.85)
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false

        let prefix = UILabel()
        prefix.text = "모아서 복습하기"
        prefix.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        prefix.textColor = UIColor(red: 0.78, green: 0.55, blue: 0.20, alpha: 1.0)
        prefix.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        let attr = NSMutableAttributedString(
            string: "틀린 문제 ",
            attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black
            ]
        )
        attr.append(NSAttributedString(
            string: "\(wrongAnswers.count)개",
            attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor(red: 0.78, green: 0.55, blue: 0.20, alpha: 1.0)
            ]
        ))
        attr.append(NSAttributedString(
            string: "가\n기다리고 있어요",
            attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: UIColor.black
            ]
        ))
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        attr.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: attr.length))
        title.attributedText = attr
        title.numberOfLines = 0
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "틀린 문제는 다시 풀 수 있어요!"
        subtitle.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = UIColor(white: 0.30, alpha: 1.0)
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(prefix)
        card.addSubview(title)
        card.addSubview(subtitle)

        NSLayoutConstraint.activate([
            prefix.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            prefix.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            prefix.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            title.topAnchor.constraint(equalTo: prefix.bottomAnchor, constant: 6),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            subtitle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subtitle.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            subtitle.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    private func makeFilterRow() -> UIView {
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)

        // 단일 노트의 오답을 모은 것이라 전체 칩만 표시.
        stack.addArrangedSubview(makeFilterChip(title: "전체 \(wrongAnswers.count)", active: true))

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scroll.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.heightAnchor),
            scroll.heightAnchor.constraint(equalToConstant: 38),
        ])
        return scroll
    }

    private func makeFilterChip(title: String, active: Bool) -> UIView {
        let label = PaddedLabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        label.padding = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        label.layer.cornerRadius = 18
        label.layer.masksToBounds = true
        if active {
            label.backgroundColor = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)
            label.textColor = .white
        } else {
            label.backgroundColor = .white
            label.textColor = UIColor(white: 0.25, alpha: 1.0)
        }
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func makeWrongAnswerCard(_ item: WrongAnswer) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        card.translatesAutoresizingMaskIntoConstraints = false

        let xCircle = UIView()
        xCircle.backgroundColor = UIColor(red: 0.98, green: 0.91, blue: 0.89, alpha: 1.0)
        xCircle.layer.cornerRadius = 13
        xCircle.translatesAutoresizingMaskIntoConstraints = false
        let xIcon = UIImageView(image: UIImage(systemName: "xmark",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)))
        xIcon.tintColor = UIColor(red: 0.82, green: 0.40, blue: 0.38, alpha: 1.0)
        xIcon.contentMode = .center
        xIcon.translatesAutoresizingMaskIntoConstraints = false
        xCircle.addSubview(xIcon)

        let tag = PaddedLabel()
        tag.text = item.categoryTag
        tag.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        tag.textColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        tag.backgroundColor = UIColor(red: 0.93, green: 0.88, blue: 0.97, alpha: 1.0)
        tag.padding = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        tag.layer.cornerRadius = 8
        tag.layer.masksToBounds = true
        tag.translatesAutoresizingMaskIntoConstraints = false

        let course = UILabel()
        course.text = "· \(item.course)"
        course.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        course.textColor = .gray
        course.lineBreakMode = .byTruncatingTail
        course.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        course.translatesAutoresizingMaskIntoConstraints = false

        let date = UILabel()
        date.text = item.date
        date.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        date.textColor = .gray
        date.translatesAutoresizingMaskIntoConstraints = false

        let question = UILabel()
        question.text = item.question
        question.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        question.textColor = .black
        question.numberOfLines = 0
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        question.attributedText = NSAttributedString(string: item.question, attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: para
        ])
        question.translatesAutoresizingMaskIntoConstraints = false

        let myAnswerBox = makeAnswerBox(title: "내 답", value: item.myAnswer,
                                         titleColor: UIColor(red: 0.82, green: 0.40, blue: 0.38, alpha: 1.0),
                                         bgColor: UIColor(red: 0.99, green: 0.93, blue: 0.91, alpha: 1.0))
        let correctBox = makeAnswerBox(title: "정답", value: item.correctAnswer,
                                        titleColor: UIColor(red: 0.30, green: 0.62, blue: 0.40, alpha: 1.0),
                                        bgColor: UIColor(red: 0.89, green: 0.95, blue: 0.87, alpha: 1.0))

        let answerStack = UIStackView(arrangedSubviews: [myAnswerBox, correctBox])
        answerStack.axis = .horizontal
        answerStack.distribution = .fillEqually
        answerStack.spacing = 8
        answerStack.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(xCircle)
        card.addSubview(tag)
        card.addSubview(course)
        card.addSubview(date)
        card.addSubview(question)
        card.addSubview(answerStack)

        NSLayoutConstraint.activate([
            xCircle.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            xCircle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            xCircle.widthAnchor.constraint(equalToConstant: 26),
            xCircle.heightAnchor.constraint(equalToConstant: 26),

            xIcon.centerXAnchor.constraint(equalTo: xCircle.centerXAnchor),
            xIcon.centerYAnchor.constraint(equalTo: xCircle.centerYAnchor),

            tag.centerYAnchor.constraint(equalTo: xCircle.centerYAnchor),
            tag.leadingAnchor.constraint(equalTo: xCircle.trailingAnchor, constant: 10),

            course.centerYAnchor.constraint(equalTo: tag.centerYAnchor),
            course.leadingAnchor.constraint(equalTo: tag.trailingAnchor, constant: 6),
            course.trailingAnchor.constraint(lessThanOrEqualTo: date.leadingAnchor, constant: -6),

            date.centerYAnchor.constraint(equalTo: tag.centerYAnchor),
            date.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            question.topAnchor.constraint(equalTo: xCircle.bottomAnchor, constant: 12),
            question.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            question.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            answerStack.topAnchor.constraint(equalTo: question.bottomAnchor, constant: 14),
            answerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            answerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            answerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
        ])
        return card
    }

    private func makeAnswerBox(title: String, value: String,
                               titleColor: UIColor, bgColor: UIColor) -> UIView {
        let container = UIView()
        container.backgroundColor = bgColor
        container.layer.cornerRadius = 10
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = titleColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let valueLabel = UILabel()
        valueLabel.text = value
        valueLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        valueLabel.textColor = .black
        valueLabel.numberOfLines = 0
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(titleLabel)
        container.addSubview(valueLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),

            valueLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            valueLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            valueLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -10),
            valueLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -10),
        ])
        return container
    }

    private func makeNioCard() -> UIView {
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        card.layer.cornerRadius = 18
        card.translatesAutoresizingMaskIntoConstraints = false

        let avatar = UIImageView(image: UIImage(named: "nio-hi"))
        avatar.contentMode = .scaleAspectFit
        avatar.translatesAutoresizingMaskIntoConstraints = false

        let name = UILabel()
        name.text = "Nio"
        name.font = UIFont.italicSystemFont(ofSize: 13)
        name.textColor = .darkGray
        name.translatesAutoresizingMaskIntoConstraints = false

        let msg = UILabel()
        msg.text = "오답을 다시 풀면 기억에 오래 남아요. 함께 해봐요!"
        msg.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        msg.textColor = .darkGray
        msg.numberOfLines = 0
        msg.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(avatar)
        card.addSubview(name)
        card.addSubview(msg)

        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            avatar.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40),

            name.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            name.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),

            msg.topAnchor.constraint(equalTo: name.bottomAnchor, constant: 2),
            msg.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 10),
            msg.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            msg.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    // MARK: - Actions

    @objc private func backTapped() { goBack() }

    @objc private func solveAllTapped() {
        let vc = RetryQuizViewController(wrongAnswers: wrongAnswers)
        if let nav = navigationController {
            nav.pushViewController(vc, animated: true)
        } else {
            present(vc, animated: true)
        }
    }
}
