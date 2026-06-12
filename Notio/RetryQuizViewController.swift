//
//  RetryQuizViewController.swift
//  Notio
//
//  오답노트에서 "다시 풀기"를 누르면 진입하는 화면.
//  틀렸던 문제만 모아, 예전에 고른 오답과 정답을 섞어 다시 맞혀본다.
//

import UIKit

class RetryQuizViewController: UIViewController {

    // MARK: - Model

    private struct RetryItem {
        let wrong: WrongAnswer
        let options: [String]   // 원래 문제의 전체 보기 (객관식)
        let correctIndex: Int
        let isShort: Bool
        let answer: String      // 주관식 정답
    }

    private let items: [RetryItem]

    private var index = 0
    private var selected: Int? = nil
    private var typed: String = ""           // 주관식 입력값
    private var revealed = false
    private var correctCount = 0
    private var finished = false

    private let accentColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
    private let correctGreen = UIColor(red: 0.30, green: 0.62, blue: 0.40, alpha: 1.0)
    private let wrongRed = UIColor(red: 0.82, green: 0.40, blue: 0.38, alpha: 1.0)

    // MARK: - Init

    init(wrongAnswers: [WrongAnswer]) {
        self.items = wrongAnswers.compactMap { wrong in
            if wrong.isShort {
                guard !wrong.answer.isEmpty else { return nil }
                return RetryItem(wrong: wrong, options: [], correctIndex: -1, isShort: true, answer: wrong.answer)
            }
            // 객관식: 원래 보기를 그대로 사용
            guard !wrong.options.isEmpty else { return nil }
            let correctIndex = wrong.options.indices.contains(wrong.correctIndex) ? wrong.correctIndex : 0
            return RetryItem(wrong: wrong, options: wrong.options, correctIndex: correctIndex, isShort: false, answer: "")
        }
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
        l.text = "다시 풀기"
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .black
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        l.textColor = UIColor(white: 0.45, alpha: 1.0)
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

    private let actionButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.layer.cornerRadius = 16
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        setupLayout()
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        actionButton.addTarget(self, action: #selector(actionTapped), for: .touchUpInside)

        if items.isEmpty {
            renderEmptyState()
        } else {
            renderQuestion()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(backButton)
        view.addSubview(navTitleLabel)
        view.addSubview(progressLabel)
        view.addSubview(scrollView)
        view.addSubview(actionButton)
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            navTitleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            navTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            progressLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -12),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            actionButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: - Render question

    private func renderQuestion() {
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let item = items[index]
        progressLabel.text = "\(index + 1) / \(items.count)"

        contentStack.addArrangedSubview(makeQuestionCard(item))
        contentStack.setCustomSpacing(8, after: contentStack.arrangedSubviews.last!)

        if item.isShort {
            contentStack.addArrangedSubview(makeShortAnswerField(item))
        } else {
            for (i, option) in item.options.enumerated() {
                contentStack.addArrangedSubview(makeOptionCard(text: option, optionIndex: i, item: item))
            }
        }

        if revealed {
            contentStack.setCustomSpacing(14, after: contentStack.arrangedSubviews.last!)
            contentStack.addArrangedSubview(makeFeedbackCard(item))
        }

        updateActionButton()
    }

    private func makeQuestionCard(_ item: RetryItem) -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 6
        card.translatesAutoresizingMaskIntoConstraints = false

        let tag = PaddedLabel()
        tag.text = item.wrong.categoryTag
        tag.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        tag.textColor = accentColor
        tag.backgroundColor = UIColor(red: 0.93, green: 0.88, blue: 0.97, alpha: 1.0)
        tag.padding = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
        tag.layer.cornerRadius = 8
        tag.layer.masksToBounds = true
        tag.translatesAutoresizingMaskIntoConstraints = false

        let course = UILabel()
        course.text = "· \(item.wrong.course)"
        course.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        course.textColor = .gray
        course.translatesAutoresizingMaskIntoConstraints = false

        let question = UILabel()
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 4
        question.attributedText = NSAttributedString(string: item.wrong.question, attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: para
        ])
        question.numberOfLines = 0
        question.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(tag)
        card.addSubview(course)
        card.addSubview(question)

        NSLayoutConstraint.activate([
            tag.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            tag.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),

            course.centerYAnchor.constraint(equalTo: tag.centerYAnchor),
            course.leadingAnchor.constraint(equalTo: tag.trailingAnchor, constant: 6),
            course.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -18),

            question.topAnchor.constraint(equalTo: tag.bottomAnchor, constant: 12),
            question.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            question.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            question.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    private func makeOptionCard(text: String, optionIndex: Int, item: RetryItem) -> UIView {
        let card = UIControl()
        card.tag = optionIndex
        card.addTarget(self, action: #selector(optionTapped(_:)), for: .touchUpInside)
        card.layer.cornerRadius = 14
        card.layer.borderWidth = 1.5
        card.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.numberOfLines = 0
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false

        let mark = UIImageView()
        mark.contentMode = .center
        mark.isUserInteractionEnabled = false
        mark.translatesAutoresizingMaskIntoConstraints = false

        // 상태별 색상
        var bg = UIColor.white
        var border = UIColor(white: 0.90, alpha: 1.0)
        var textColor = UIColor.black
        var markImage: UIImage? = nil
        var markTint = UIColor.clear

        if revealed {
            card.isUserInteractionEnabled = false
            if optionIndex == item.correctIndex {
                bg = UIColor(red: 0.89, green: 0.95, blue: 0.87, alpha: 1.0)
                border = correctGreen
                textColor = UIColor(red: 0.20, green: 0.45, blue: 0.28, alpha: 1.0)
                markImage = UIImage(systemName: "checkmark.circle.fill")
                markTint = correctGreen
            } else if optionIndex == selected {
                bg = UIColor(red: 0.99, green: 0.93, blue: 0.91, alpha: 1.0)
                border = wrongRed
                textColor = UIColor(red: 0.62, green: 0.28, blue: 0.26, alpha: 1.0)
                markImage = UIImage(systemName: "xmark.circle.fill")
                markTint = wrongRed
            }
        } else if optionIndex == selected {
            bg = UIColor(red: 0.95, green: 0.92, blue: 0.98, alpha: 1.0)
            border = accentColor
            textColor = accentColor
        }

        card.backgroundColor = bg
        card.layer.borderColor = border.cgColor
        label.textColor = textColor
        mark.image = markImage?.withConfiguration(UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold))
        mark.tintColor = markTint

        card.addSubview(label)
        card.addSubview(mark)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: mark.leadingAnchor, constant: -8),

            mark.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            mark.centerYAnchor.constraint(equalTo: card.centerYAnchor),
            mark.widthAnchor.constraint(equalToConstant: 22),
        ])
        return card
    }

    private func makeShortAnswerField(_ item: RetryItem) -> UIView {
        let field = PaddedTextField()
        field.placeholder = "정답을 입력하세요"
        field.text = typed
        field.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        field.backgroundColor = .white
        field.layer.cornerRadius = 12
        field.layer.borderWidth = 1.5
        field.autocorrectionType = .no
        field.isEnabled = !revealed
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 54).isActive = true
        field.addTarget(self, action: #selector(typedChanged(_:)), for: .editingChanged)

        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "정답 확인", style: .done, target: self, action: #selector(actionTapped))
        ]
        field.inputAccessoryView = toolbar

        if revealed {
            let ok = AnswerMatcher.isCorrect(typed: typed, correct: item.answer)
            field.layer.borderColor = (ok ? correctGreen : wrongRed).cgColor
            field.backgroundColor = ok
                ? UIColor(red: 0.89, green: 0.95, blue: 0.87, alpha: 1.0)
                : UIColor(red: 0.99, green: 0.93, blue: 0.91, alpha: 1.0)
        } else {
            field.layer.borderColor = UIColor(white: 0.85, alpha: 1.0).cgColor
        }
        return field
    }

    @objc private func typedChanged(_ sender: UITextField) {
        typed = sender.text ?? ""
        updateActionButton()
    }
    @objc private func dismissKeyboard() { view.endEditing(true) }

    private func makeFeedbackCard(_ item: RetryItem) -> UIView {
        let isCorrect = item.isShort
            ? AnswerMatcher.isCorrect(typed: typed, correct: item.answer)
            : (selected == item.correctIndex)
        let card = UIView()
        card.backgroundColor = (isCorrect ? correctGreen : wrongRed).withAlphaComponent(0.10)
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        let icon = UIImageView(image: UIImage(systemName: isCorrect ? "hand.thumbsup.fill" : "lightbulb.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)))
        icon.tintColor = isCorrect ? correctGreen : wrongRed
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.textColor = UIColor(white: 0.25, alpha: 1.0)
        let correctText = item.isShort
            ? item.answer
            : (item.options.indices.contains(item.correctIndex) ? item.options[item.correctIndex] : "-")
        label.text = isCorrect
            ? "정답이에요! 이제 확실히 기억하고 있네요."
            : "아직 헷갈려요. 정답은 \"\(correctText)\" 예요."
        label.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(icon)
        card.addSubview(label)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            icon.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            icon.widthAnchor.constraint(equalToConstant: 18),

            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 10),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
        ])
        return card
    }

    // MARK: - Result

    private func renderResult() {
        finished = true
        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        progressLabel.text = nil

        let percent = items.isEmpty ? 0 : Int(round(Double(correctCount) / Double(items.count) * 100))

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.05
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        let avatar = UIImageView(image: UIImage(named: percent >= 100 ? "nio-wow" : "nio-hi"))
        avatar.contentMode = .scaleAspectFit
        avatar.translatesAutoresizingMaskIntoConstraints = false

        let title = UILabel()
        title.text = percent >= 100 ? "전부 다 맞혔어요!" : "다시 풀기 완료!"
        title.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        title.textColor = .black
        title.textAlignment = .center
        title.translatesAutoresizingMaskIntoConstraints = false

        let score = UILabel()
        let attr = NSMutableAttributedString(
            string: "\(items.count)문제 중 ",
            attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .regular),
                         .foregroundColor: UIColor.darkGray])
        attr.append(NSAttributedString(
            string: "\(correctCount)개 정답",
            attributes: [.font: UIFont.systemFont(ofSize: 15, weight: .bold),
                         .foregroundColor: accentColor]))
        score.attributedText = attr
        score.textAlignment = .center
        score.translatesAutoresizingMaskIntoConstraints = false

        let percentLabel = UILabel()
        percentLabel.text = "\(percent)%"
        percentLabel.font = UIFont.systemFont(ofSize: 40, weight: .bold)
        percentLabel.textColor = accentColor
        percentLabel.textAlignment = .center
        percentLabel.translatesAutoresizingMaskIntoConstraints = false

        let hint = UILabel()
        hint.text = correctCount == items.count
            ? "전부 다시 맞혔어요! 잘했어요 🎉"
            : "아직 헷갈리는 문제는 다음에 또 풀어봐요!"
        hint.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        hint.textColor = .gray
        hint.numberOfLines = 0
        hint.textAlignment = .center
        hint.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(avatar)
        card.addSubview(title)
        card.addSubview(percentLabel)
        card.addSubview(score)
        card.addSubview(hint)

        NSLayoutConstraint.activate([
            avatar.topAnchor.constraint(equalTo: card.topAnchor, constant: 28),
            avatar.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 72),
            avatar.heightAnchor.constraint(equalToConstant: 72),

            title.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 14),
            title.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            title.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            percentLabel.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            percentLabel.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            score.topAnchor.constraint(equalTo: percentLabel.bottomAnchor, constant: 2),
            score.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            score.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            hint.topAnchor.constraint(equalTo: score.bottomAnchor, constant: 16),
            hint.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            hint.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            hint.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -26),
        ])

        contentStack.addArrangedSubview(card)
        updateActionButton()
    }

    private func renderEmptyState() {
        progressLabel.text = nil
        let label = UILabel()
        label.text = "다시 풀 오답이 없어요."
        label.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        contentStack.addArrangedSubview(label)
        actionButton.setTitle("오답노트로 돌아가기", for: .normal)
        actionButton.backgroundColor = accentColor
        actionButton.isEnabled = true
    }

    // MARK: - Action button state

    private func updateActionButton() {
        let isLast = index == items.count - 1

        if finished {
            actionButton.setTitle("오답노트로 돌아가기", for: .normal)
        } else if !revealed {
            actionButton.setTitle("정답 확인", for: .normal)
        } else {
            actionButton.setTitle(isLast ? "결과 보기" : "다음 문제", for: .normal)
        }

        let answered: Bool
        if revealed || finished {
            answered = true
        } else if items.indices.contains(index), items[index].isShort {
            answered = !typed.trimmingCharacters(in: .whitespaces).isEmpty
        } else {
            answered = (selected != nil)
        }
        actionButton.isEnabled = answered
        actionButton.backgroundColor = answered ? accentColor : UIColor(white: 0.78, alpha: 1.0)
    }

    // MARK: - Actions

    @objc private func optionTapped(_ sender: UIControl) {
        guard !revealed else { return }
        selected = sender.tag
        renderQuestion()
    }

    @objc private func actionTapped() {
        // 빈 상태이거나 결과 화면이면 오답노트로 복귀
        if items.isEmpty || finished {
            goBack(); return
        }

        let item = items[index]
        if !revealed {
            // 응답 여부 확인
            let isCorrect: Bool
            if item.isShort {
                view.endEditing(true)
                guard !typed.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                isCorrect = AnswerMatcher.isCorrect(typed: typed, correct: item.answer)
            } else {
                guard let selected else { return }
                isCorrect = (selected == item.correctIndex)
            }
            revealed = true
            if isCorrect { correctCount += 1 }
            renderQuestion()
            DispatchQueue.main.async {
                let bottom = self.scrollView.contentSize.height - self.scrollView.bounds.height
                if bottom > 0 { self.scrollView.setContentOffset(CGPoint(x: 0, y: bottom), animated: true) }
            }
        } else if index < items.count - 1 {
            index += 1
            selected = nil
            typed = ""
            revealed = false
            renderQuestion()
            scrollView.setContentOffset(.zero, animated: false)
        } else {
            renderResult()
            scrollView.setContentOffset(.zero, animated: false)
        }
    }

    @objc private func backTapped() { goBack() }
}
