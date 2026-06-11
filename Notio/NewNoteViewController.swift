//
//  NewNoteViewController.swift
//  Notio
//

import UIKit

class NewNoteViewController: UIViewController {

    // MARK: - State

    private var selectedCategoryIndex: Int? = nil
    private var selectedDifficultyIndex: Int? = 1 // 중급 기본 선택

    private let categoryOptions = ["전공", "교양", "자격증", "기타"]
    private let difficultyOptions = ["기초", "중급", "심화"]

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

    // MARK: - UI Components

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Nav bar
    private let backButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        button.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)
        button.tintColor = .black
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let navTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "새 노트"
        label.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // Character card
    private let characterCard: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.5)
        view.layer.cornerRadius = 20
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let characterImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "ready"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let characterTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "강의 자료를 들려주세요"
        label.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        label.textColor = .black
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let characterSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "PDF를 올려주시면 Nio가"
        label.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // PDF button
    private let pdfButton: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.87, green: 0.84, blue: 0.93, alpha: 0.5)
        view.layer.cornerRadius = 14
        view.layer.borderWidth = 1.5
        view.layer.borderColor = UIColor(red: 0.75, green: 0.70, blue: 0.85, alpha: 0.6).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let pdfTitleLabel: UILabel = {
        let label = UILabel()
        label.text = "PDF 파일 선택"
        label.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let pdfSubtitleLabel: UILabel = {
        let label = UILabel()
        label.text = "파일 앱에서 불러오기"
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // 노트 제목
    private let noteTitleSectionLabel: UILabel = {
        let label = UILabel()
        label.text = "노트 제목"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let noteTitleTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "예: 운영체제론 3강"
        tf.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        tf.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        tf.layer.cornerRadius = 12
        tf.layer.borderWidth = 1
        tf.layer.borderColor = UIColor(red: 0.88, green: 0.86, blue: 0.90, alpha: 1.0).cgColor
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 0))
        tf.leftViewMode = .always
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    // 과목 분류
    private let categorySectionLabel: UILabel = {
        let label = UILabel()
        label.text = "과목 분류"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let categoryStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // 난이도
    private let difficultySectionLabel: UILabel = {
        let label = UILabel()
        label.text = "난이도"
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let difficultyStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // Bottom button
    private let submitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("파일을 선택해주세요", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.6), for: .normal)
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
        setupChips()

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        // Nav bar
        contentView.addSubview(backButton)
        contentView.addSubview(navTitleLabel)

        // Character card
        contentView.addSubview(characterCard)
        characterCard.addSubview(characterImageView)
        characterCard.addSubview(characterTitleLabel)
        characterCard.addSubview(characterSubtitleLabel)

        // PDF button
        contentView.addSubview(pdfButton)
        pdfButton.addSubview(pdfTitleLabel)
        pdfButton.addSubview(pdfSubtitleLabel)

        // 노트 제목
        contentView.addSubview(noteTitleSectionLabel)
        contentView.addSubview(noteTitleTextField)

        // 과목 분류
        contentView.addSubview(categorySectionLabel)
        contentView.addSubview(categoryStackView)

        // 난이도
        contentView.addSubview(difficultySectionLabel)
        contentView.addSubview(difficultyStackView)

        // Bottom button
        view.addSubview(submitButton)

        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: submitButton.topAnchor, constant: -12),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Nav
            backButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            backButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            navTitleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            navTitleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),

            // Character card
            characterCard.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 20),
            characterCard.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            characterCard.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            characterImageView.topAnchor.constraint(equalTo: characterCard.topAnchor, constant: 24),
            characterImageView.centerXAnchor.constraint(equalTo: characterCard.centerXAnchor),
            characterImageView.widthAnchor.constraint(equalToConstant: 120),
            characterImageView.heightAnchor.constraint(equalToConstant: 120),

            characterTitleLabel.topAnchor.constraint(equalTo: characterImageView.bottomAnchor, constant: 16),
            characterTitleLabel.centerXAnchor.constraint(equalTo: characterCard.centerXAnchor),

            characterSubtitleLabel.topAnchor.constraint(equalTo: characterTitleLabel.bottomAnchor, constant: 6),
            characterSubtitleLabel.centerXAnchor.constraint(equalTo: characterCard.centerXAnchor),
            characterSubtitleLabel.bottomAnchor.constraint(equalTo: characterCard.bottomAnchor, constant: -24),

            // PDF button
            pdfButton.topAnchor.constraint(equalTo: characterCard.bottomAnchor, constant: 16),
            pdfButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            pdfButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            pdfButton.heightAnchor.constraint(equalToConstant: 60),

            pdfTitleLabel.topAnchor.constraint(equalTo: pdfButton.topAnchor, constant: 12),
            pdfTitleLabel.centerXAnchor.constraint(equalTo: pdfButton.centerXAnchor),

            pdfSubtitleLabel.topAnchor.constraint(equalTo: pdfTitleLabel.bottomAnchor, constant: 2),
            pdfSubtitleLabel.centerXAnchor.constraint(equalTo: pdfButton.centerXAnchor),

            // 노트 제목
            noteTitleSectionLabel.topAnchor.constraint(equalTo: pdfButton.bottomAnchor, constant: 28),
            noteTitleSectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            noteTitleTextField.topAnchor.constraint(equalTo: noteTitleSectionLabel.bottomAnchor, constant: 10),
            noteTitleTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            noteTitleTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            noteTitleTextField.heightAnchor.constraint(equalToConstant: 48),

            // 과목 분류
            categorySectionLabel.topAnchor.constraint(equalTo: noteTitleTextField.bottomAnchor, constant: 28),
            categorySectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            categoryStackView.topAnchor.constraint(equalTo: categorySectionLabel.bottomAnchor, constant: 10),
            categoryStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            // 난이도
            difficultySectionLabel.topAnchor.constraint(equalTo: categoryStackView.bottomAnchor, constant: 28),
            difficultySectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            difficultyStackView.topAnchor.constraint(equalTo: difficultySectionLabel.bottomAnchor, constant: 10),
            difficultyStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            difficultyStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -30),

            // Submit button
            submitButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            submitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            submitButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            submitButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func setupChips() {
        // 과목 분류 chips
        for (index, title) in categoryOptions.enumerated() {
            let button = makeChipButton(title: title, tag: index)
            button.addTarget(self, action: #selector(categoryChipTapped(_:)), for: .touchUpInside)
            updateChipButton(button, isSelected: false)
            categoryStackView.addArrangedSubview(button)
        }

        // 난이도 chips
        for (index, title) in difficultyOptions.enumerated() {
            let button = makeChipButton(title: title, tag: 100 + index)
            button.addTarget(self, action: #selector(difficultyChipTapped(_:)), for: .touchUpInside)
            updateChipButton(button, isSelected: index == selectedDifficultyIndex)
            difficultyStackView.addArrangedSubview(button)
        }
    }

    private func makeChipButton(title: String, tag: Int) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.layer.cornerRadius = 18
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 18, bottom: 8, right: 18)
        button.tag = tag
        return button
    }

    private func updateChipButton(_ button: UIButton, isSelected: Bool) {
        if isSelected {
            button.backgroundColor = UIColor(red: 0.22, green: 0.22, blue: 0.25, alpha: 1.0)
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = UIColor.white.withAlphaComponent(0.6)
            button.setTitleColor(.darkGray, for: .normal)
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor(red: 0.85, green: 0.83, blue: 0.88, alpha: 1.0).cgColor
        }
    }

    // MARK: - Actions

    @objc private func backTapped() {
        dismiss(animated: true)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    @objc private func categoryChipTapped(_ sender: UIButton) {
        selectedCategoryIndex = sender.tag
        for case let button as UIButton in categoryStackView.arrangedSubviews {
            updateChipButton(button, isSelected: button.tag == selectedCategoryIndex)
        }
    }

    @objc private func difficultyChipTapped(_ sender: UIButton) {
        selectedDifficultyIndex = sender.tag - 100
        for case let button as UIButton in difficultyStackView.arrangedSubviews {
            updateChipButton(button, isSelected: button.tag == sender.tag)
        }
    }
}
