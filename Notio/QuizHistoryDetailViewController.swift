//
//  QuizHistoryDetailViewController.swift
//  Notio
//
//  각 퀴즈 기록의 상세 내역(문제별 내 답·정답)을 조회하는 화면.
//

import UIKit

class QuizHistoryDetailViewController: UIViewController {

    private let entry: QuizHistoryEntry
    private let noteTitle: String

    init(entry: QuizHistoryEntry, noteTitle: String) {
        self.entry = entry
        self.noteTitle = noteTitle
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Derived

    private var correctCount: Int { entry.results.filter { $0.isCorrect }.count }
    private var totalCount: Int { entry.results.count }

    private func accentColor(for percent: Int) -> UIColor {
        if percent >= 100 {
            return UIColor(red: 0.30, green: 0.62, blue: 0.40, alpha: 1.0) // green
        } else if percent >= 80 {
            return UIColor(red: 0.30, green: 0.45, blue: 0.85, alpha: 1.0) // blue
        } else if percent >= 60 {
            return UIColor(red: 0.86, green: 0.55, blue: 0.30, alpha: 1.0) // orange
        } else {
            return UIColor(red: 0.82, green: 0.40, blue: 0.38, alpha: 1.0) // red
        }
    }

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
        l.text = "퀴즈 결과"
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .black
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
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
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(backButton)
        view.addSubview(navTitleLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            navTitleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            navTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

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
        contentStack.addArrangedSubview(makeSummaryCard())
        contentStack.setCustomSpacing(18, after: contentStack.arrangedSubviews.last!)

        contentStack.addArrangedSubview(makeSectionHeader("문제별 내역 · \(totalCount)문항"))
        contentStack.setCustomSpacing(10, after: contentStack.arrangedSubviews.last!)

        for (idx, result) in entry.results.enumerated() {
            contentStack.addArrangedSubview(makeResultCard(number: idx + 1, result: result))
        }
    }

    // MARK: - Summary card

    private func makeSummaryCard() -> UIView {
        let accent = accentColor(for: entry.percent)

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        // 좌측: 노트 제목 + 날짜
        let noteLabel = UILabel()
        noteLabel.text = noteTitle
        noteLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        noteLabel.textColor = accent
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        let dateLabel = UILabel()
        dateLabel.text = "\(entry.date) \(entry.weekday)"
        dateLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        dateLabel.textColor = .black
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        // 소요 시간
        let clock = UIImageView(image: UIImage(systemName: "clock",
                                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium)))
        clock.tintColor = .gray
        clock.translatesAutoresizingMaskIntoConstraints = false

        let durationLabel = UILabel()
        durationLabel.text = entry.duration
        durationLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        durationLabel.textColor = .gray
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        // 우측: 퍼센트 배지
        let percentBadge = UIView()
        percentBadge.backgroundColor = accent.withAlphaComponent(0.12)
        percentBadge.layer.cornerRadius = 34
        percentBadge.translatesAutoresizingMaskIntoConstraints = false

        let percentValue = UILabel()
        percentValue.text = "\(entry.percent)%"
        percentValue.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        percentValue.textColor = accent
        percentValue.translatesAutoresizingMaskIntoConstraints = false

        let scoreValue = UILabel()
        scoreValue.text = "\(correctCount)/\(totalCount)"
        scoreValue.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        scoreValue.textColor = accent.withAlphaComponent(0.8)
        scoreValue.translatesAutoresizingMaskIntoConstraints = false

        percentBadge.addSubview(percentValue)
        percentBadge.addSubview(scoreValue)

        card.addSubview(noteLabel)
        card.addSubview(dateLabel)
        card.addSubview(clock)
        card.addSubview(durationLabel)
        card.addSubview(percentBadge)

        NSLayoutConstraint.activate([
            noteLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            noteLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            noteLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentBadge.leadingAnchor, constant: -12),

            dateLabel.topAnchor.constraint(equalTo: noteLabel.bottomAnchor, constant: 6),
            dateLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            dateLabel.trailingAnchor.constraint(lessThanOrEqualTo: percentBadge.leadingAnchor, constant: -12),

            clock.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 12),
            clock.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            clock.widthAnchor.constraint(equalToConstant: 13),
            clock.heightAnchor.constraint(equalToConstant: 13),
            clock.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20),

            durationLabel.centerYAnchor.constraint(equalTo: clock.centerYAnchor),
            durationLabel.leadingAnchor.constraint(equalTo: clock.trailingAnchor, constant: 5),

            percentBadge.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            percentBadge.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            percentBadge.widthAnchor.constraint(equalToConstant: 68),
            percentBadge.heightAnchor.constraint(equalToConstant: 68),

            percentValue.centerXAnchor.constraint(equalTo: percentBadge.centerXAnchor),
            percentValue.topAnchor.constraint(equalTo: percentBadge.topAnchor, constant: 16),

            scoreValue.centerXAnchor.constraint(equalTo: percentBadge.centerXAnchor),
            scoreValue.topAnchor.constraint(equalTo: percentValue.bottomAnchor, constant: 0),
        ])
        return card
    }

    private func makeSectionHeader(_ text: String) -> UIView {
        let container = UIView()
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 4),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -4),
        ])
        return container
    }

    // MARK: - Result card

    private func makeResultCard(number: Int, result: QuizAnswerResult) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        card.translatesAutoresizingMaskIntoConstraints = false

        let correctGreen = UIColor(red: 0.30, green: 0.62, blue: 0.40, alpha: 1.0)
        let wrongRed = UIColor(red: 0.82, green: 0.40, blue: 0.38, alpha: 1.0)
        let markColor = result.isCorrect ? correctGreen : wrongRed

        // O / X 마크
        let markCircle = UIView()
        markCircle.backgroundColor = result.isCorrect
            ? UIColor(red: 0.89, green: 0.95, blue: 0.87, alpha: 1.0)
            : UIColor(red: 0.98, green: 0.91, blue: 0.89, alpha: 1.0)
        markCircle.layer.cornerRadius = 13
        markCircle.translatesAutoresizingMaskIntoConstraints = false
        let markIcon = UIImageView(image: UIImage(systemName: result.isCorrect ? "checkmark" : "xmark",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .bold)))
        markIcon.tintColor = markColor
        markIcon.contentMode = .center
        markIcon.translatesAutoresizingMaskIntoConstraints = false
        markCircle.addSubview(markIcon)

        let numberLabel = UILabel()
        numberLabel.text = "Q\(number)"
        numberLabel.font = UIFont.systemFont(ofSize: 13, weight: .bold)
        numberLabel.textColor = .black
        numberLabel.translatesAutoresizingMaskIntoConstraints = false

        let tag = PaddedLabel()
        tag.text = result.kind
        tag.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        tag.textColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
        tag.backgroundColor = UIColor(red: 0.93, green: 0.88, blue: 0.97, alpha: 1.0)
        tag.padding = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        tag.layer.cornerRadius = 8
        tag.layer.masksToBounds = true
        tag.translatesAutoresizingMaskIntoConstraints = false

        let question = UILabel()
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        question.attributedText = NSAttributedString(string: result.question, attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: para
        ])
        question.numberOfLines = 0
        question.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(markCircle)
        card.addSubview(numberLabel)
        card.addSubview(tag)
        card.addSubview(question)

        let myAnswerBox = makeAnswerBox(
            title: "내 답", value: result.myAnswer,
            titleColor: result.isCorrect ? correctGreen : wrongRed,
            bgColor: result.isCorrect
                ? UIColor(red: 0.89, green: 0.95, blue: 0.87, alpha: 1.0)
                : UIColor(red: 0.99, green: 0.93, blue: 0.91, alpha: 1.0))

        var lastBottom: NSLayoutYAxisAnchor

        if result.isCorrect {
            // 정답인 경우 내 답만 표시
            card.addSubview(myAnswerBox)
            NSLayoutConstraint.activate([
                myAnswerBox.topAnchor.constraint(equalTo: question.bottomAnchor, constant: 14),
                myAnswerBox.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                myAnswerBox.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            ])
            lastBottom = myAnswerBox.bottomAnchor
        } else {
            // 오답인 경우 내 답 + 정답 나란히 표시
            let correctBox = makeAnswerBox(
                title: "정답", value: result.correctAnswer,
                titleColor: correctGreen,
                bgColor: UIColor(red: 0.89, green: 0.95, blue: 0.87, alpha: 1.0))
            let answerStack = UIStackView(arrangedSubviews: [myAnswerBox, correctBox])
            answerStack.axis = .horizontal
            answerStack.distribution = .fillEqually
            answerStack.spacing = 8
            answerStack.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(answerStack)
            NSLayoutConstraint.activate([
                answerStack.topAnchor.constraint(equalTo: question.bottomAnchor, constant: 14),
                answerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                answerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            ])
            lastBottom = answerStack.bottomAnchor
        }

        NSLayoutConstraint.activate([
            markCircle.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            markCircle.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            markCircle.widthAnchor.constraint(equalToConstant: 26),
            markCircle.heightAnchor.constraint(equalToConstant: 26),

            markIcon.centerXAnchor.constraint(equalTo: markCircle.centerXAnchor),
            markIcon.centerYAnchor.constraint(equalTo: markCircle.centerYAnchor),

            numberLabel.centerYAnchor.constraint(equalTo: markCircle.centerYAnchor),
            numberLabel.leadingAnchor.constraint(equalTo: markCircle.trailingAnchor, constant: 10),

            tag.centerYAnchor.constraint(equalTo: markCircle.centerYAnchor),
            tag.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 8),

            question.topAnchor.constraint(equalTo: markCircle.bottomAnchor, constant: 12),
            question.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            question.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),

            lastBottom.constraint(equalTo: card.bottomAnchor, constant: -16),
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

    // MARK: - Actions

    @objc private func backTapped() { goBack() }
}
