//
//  NewQuizConfigViewController.swift
//  Notio
//
//  "새 문제 만들기"를 누르면 뜨는 설정 시트.
//  난이도(상/중/하)와 문제 수를 정해 Gemini에 새 퀴즈 생성을 요청한다.
//

import UIKit

class NewQuizConfigViewController: UIViewController {

    /// 생성 버튼을 누르면 선택한 (난이도, 문제 수)로 호출된다.
    var onGenerate: ((QuizDifficulty, Int) -> Void)?

    private let accentColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
    private let darkColor = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)

    // 상(hard) → 중(medium) → 하(easy) 순으로 노출
    private let difficulties: [QuizDifficulty] = [.hard, .medium, .easy]
    private var selectedDifficulty: QuizDifficulty = .medium
    private var questionCount: Int = 5

    private var difficultyButtons: [UIButton] = []

    private let countField: UITextField = {
        let tf = UITextField()
        tf.text = "5"
        tf.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        tf.textColor = .black
        tf.textAlignment = .center
        tf.keyboardType = .numberPad
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let stepper: UIStepper = {
        let s = UIStepper()
        s.minimumValue = 1
        s.maximumValue = 20
        s.value = 5
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let generateButton = LoginViewController.makePillButton(title: "문제 생성하기", filled: true)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.97, alpha: 1.0)
        setupLayout()
        stepper.addTarget(self, action: #selector(stepperChanged), for: .valueChanged)
        countField.addTarget(self, action: #selector(countFieldChanged), for: .editingChanged)
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func setupLayout() {
        let titleLabel = UILabel()
        titleLabel.text = "새 문제 만들기"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .black
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "난이도와 문제 수를 정하면 AI가 새 문제를 만들어요"
        subtitle.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        subtitle.textColor = .gray
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        let diffLabel = sectionLabel("난이도")
        let difficultyRow = makeDifficultyRow()
        let countLabel = sectionLabel("문제 수  (1~20)")
        let countRow = makeCountRow()

        [titleLabel, subtitle, diffLabel, difficultyRow, countLabel, countRow, generateButton]
            .forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            subtitle.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitle.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitle.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            diffLabel.topAnchor.constraint(equalTo: subtitle.bottomAnchor, constant: 26),
            diffLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            difficultyRow.topAnchor.constraint(equalTo: diffLabel.bottomAnchor, constant: 12),
            difficultyRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            difficultyRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            difficultyRow.heightAnchor.constraint(equalToConstant: 52),

            countLabel.topAnchor.constraint(equalTo: difficultyRow.bottomAnchor, constant: 26),
            countLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            countRow.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 12),
            countRow.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            countRow.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            countRow.heightAnchor.constraint(equalToConstant: 56),

            generateButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            generateButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            generateButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            generateButton.heightAnchor.constraint(equalToConstant: 54),
        ])

        updateDifficultyButtons()
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        l.textColor = UIColor(white: 0.35, alpha: 1.0)
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeDifficultyRow() -> UIView {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false

        for (idx, diff) in difficulties.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(diff.rawValue, for: .normal)
            b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
            b.layer.cornerRadius = 14
            b.tag = idx
            b.addTarget(self, action: #selector(difficultyTapped(_:)), for: .touchUpInside)
            difficultyButtons.append(b)
            stack.addArrangedSubview(b)
        }
        return stack
    }

    private func makeCountRow() -> UIView {
        let container = UIView()
        container.backgroundColor = .white
        container.layer.cornerRadius = 14
        container.translatesAutoresizingMaskIntoConstraints = false

        let unit = UILabel()
        unit.text = "문제"
        unit.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        unit.textColor = .gray
        unit.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(countField)
        container.addSubview(unit)
        container.addSubview(stepper)

        NSLayoutConstraint.activate([
            countField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            countField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            countField.widthAnchor.constraint(equalToConstant: 50),

            unit.leadingAnchor.constraint(equalTo: countField.trailingAnchor, constant: 2),
            unit.centerYAnchor.constraint(equalTo: container.centerYAnchor),

            stepper.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stepper.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])
        return container
    }

    private func updateDifficultyButtons() {
        for (idx, b) in difficultyButtons.enumerated() {
            let isSelected = difficulties[idx] == selectedDifficulty
            b.backgroundColor = isSelected ? darkColor : .white
            b.setTitleColor(isSelected ? .white : UIColor(white: 0.4, alpha: 1.0), for: .normal)
            b.layer.borderWidth = isSelected ? 0 : 1
            b.layer.borderColor = UIColor(white: 0.88, alpha: 1.0).cgColor
        }
    }

    // MARK: - Actions

    @objc private func difficultyTapped(_ sender: UIButton) {
        selectedDifficulty = difficulties[sender.tag]
        updateDifficultyButtons()
    }

    @objc private func stepperChanged() {
        questionCount = Int(stepper.value)
        countField.text = "\(questionCount)"
    }

    @objc private func countFieldChanged() {
        let n = Int(countField.text ?? "") ?? 5
        questionCount = min(max(n, 1), 20)
        stepper.value = Double(questionCount)
    }

    @objc private func generateTapped() {
        view.endEditing(true)
        // 범위 보정
        questionCount = min(max(questionCount, 1), 20)
        let handler = onGenerate
        let difficulty = selectedDifficulty
        let count = questionCount
        dismiss(animated: true) {
            handler?(difficulty, count)
        }
    }
}
