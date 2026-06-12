//
//  SignupViewController.swift
//  Notio
//
//  로컬 회원가입 화면. 유효성 검사 + 이메일 중복 확인.
//  약관 동의는 보여주기용 UI일 뿐 따로 저장하지 않는다.
//

import UIKit

class SignupViewController: UIViewController {

    private let accentColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
    private let darkColor = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)

    // 약관 동의 상태 (저장하지 않고 화면 내에서만 사용)
    private var agreeService = false   // 필수
    private var agreePrivacy = false   // 필수
    private var agreeMarketing = false // 선택
    private var serviceRow: TermRow!
    private var privacyRow: TermRow!
    private var marketingRow: TermRow!
    private var allAgreeRow: TermRow!

    // MARK: - UI

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.87, green: 0.84, blue: 0.93, alpha: 1.0).cgColor,
            UIColor(red: 0.96, green: 0.92, blue: 0.86, alpha: 1.0).cgColor
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
        l.text = "회원가입"
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .black
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        sv.keyboardDismissMode = .interactive
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let contentStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 16
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let nicknameField = LabeledField(title: "닉네임", placeholder: "닉네임 입력")
    private let emailField = LabeledField(title: "이메일", placeholder: "이메일 입력", keyboard: .emailAddress)
    private let passwordField = LabeledField(title: "비밀번호", placeholder: "8자 이상 입력", secure: true)
    private let confirmField = LabeledField(title: "비밀번호 확인", placeholder: "비밀번호 재입력", secure: true)

    private let submitButton = LoginViewController.makePillButton(title: "가입하고 시작하기  →", filled: true)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        setupLayout()

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        emailField.textField.addTarget(self, action: #selector(emailChanged), for: .editingChanged)

        let tap = UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
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

        contentStack.addArrangedSubview(makeHeader())
        contentStack.setCustomSpacing(24, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(nicknameField)
        contentStack.addArrangedSubview(emailField)
        contentStack.addArrangedSubview(passwordField)
        contentStack.addArrangedSubview(confirmField)
        contentStack.setCustomSpacing(20, after: confirmField)
        contentStack.addArrangedSubview(makeTermsCard())
        contentStack.setCustomSpacing(24, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(submitButton)

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
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -28),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -56),

            submitButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func makeHeader() -> UIView {
        let container = UIView()
        let title = UILabel()
        let attr = NSMutableAttributedString(string: "Notio", attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: accentColor
        ])
        attr.append(NSAttributedString(string: "에 처음이시군요", attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .bold),
            .foregroundColor: UIColor.black
        ]))
        title.attributedText = attr
        title.translatesAutoresizingMaskIntoConstraints = false

        let subtitle = UILabel()
        subtitle.text = "몇 가지 정보만 입력하면 바로 시작할 수 있어요"
        subtitle.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitle.textColor = UIColor(white: 0.4, alpha: 1.0)
        subtitle.numberOfLines = 0
        subtitle.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(title)
        container.addSubview(subtitle)
        NSLayoutConstraint.activate([
            title.topAnchor.constraint(equalTo: container.topAnchor),
            title.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 8),
            subtitle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            subtitle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeTermsCard() -> UIView {
        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false

        allAgreeRow = TermRow(title: "전체 동의", bold: true, showChevron: false)
        allAgreeRow.onToggle = { [weak self] on in self?.setAllAgree(on) }

        serviceRow = TermRow(title: "(필수) 서비스 이용약관", bold: false, showChevron: true)
        serviceRow.onToggle = { [weak self] on in self?.agreeService = on; self?.syncAllAgree() }
        serviceRow.onChevron = { [weak self] in self?.showTerm("서비스 이용약관") }

        privacyRow = TermRow(title: "(필수) 개인정보 처리방침", bold: false, showChevron: true)
        privacyRow.onToggle = { [weak self] on in self?.agreePrivacy = on; self?.syncAllAgree() }
        privacyRow.onChevron = { [weak self] in self?.showTerm("개인정보 처리방침") }

        marketingRow = TermRow(title: "(선택) 마케팅 정보 수신", bold: false, showChevron: true)
        marketingRow.onToggle = { [weak self] on in self?.agreeMarketing = on; self?.syncAllAgree() }
        marketingRow.onChevron = { [weak self] in self?.showTerm("마케팅 정보 수신") }

        let divider = UIView()
        divider.backgroundColor = UIColor(white: 0.92, alpha: 1.0)
        divider.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [allAgreeRow, divider, serviceRow, privacyRow, marketingRow])
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)

        NSLayoutConstraint.activate([
            divider.heightAnchor.constraint(equalToConstant: 1),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 6),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -6),
        ])
        return card
    }

    // MARK: - Terms logic

    private func setAllAgree(_ on: Bool) {
        agreeService = on; agreePrivacy = on; agreeMarketing = on
        serviceRow.setChecked(on)
        privacyRow.setChecked(on)
        marketingRow.setChecked(on)
    }

    private func syncAllAgree() {
        allAgreeRow.setChecked(agreeService && agreePrivacy && agreeMarketing)
    }

    private func showTerm(_ name: String) {
        let alert = UIAlertController(title: name,
                                      message: "\(name) 전문은 추후 제공될 예정이에요.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    // MARK: - Validation / Actions

    @objc private func backTapped() { goBack() }

    @objc private func emailChanged() {
        let email = emailField.text
        guard !email.isEmpty else { emailField.setAccessory(nil, ok: false); return }
        if !Validator.isValidEmail(email) {
            emailField.setAccessory(nil, ok: false)
        } else if DataStore.shared.emailExists(email) {
            emailField.setAccessory("이미 사용 중", ok: false)
        } else {
            emailField.setAccessory("✓ 사용 가능", ok: true)
        }
    }

    @objc private func submitTapped() {
        view.endEditing(true)
        [nicknameField, emailField, passwordField, confirmField].forEach { $0.setError(nil) }

        let nickname = nicknameField.text
        let email = emailField.text
        let password = passwordField.text
        let confirm = confirmField.text

        guard !nickname.isEmpty else { nicknameField.setError("닉네임을 입력해주세요"); return }
        guard !email.isEmpty else { emailField.setError("이메일을 입력해주세요"); return }
        guard Validator.isValidEmail(email) else {
            emailField.setError("올바른 이메일 형식이 아니에요"); return
        }
        guard !DataStore.shared.emailExists(email) else {
            emailField.setError("이미 가입된 이메일이에요"); return
        }
        guard Validator.isValidPassword(password) else {
            passwordField.setError("비밀번호는 8자 이상이어야 해요"); return
        }
        guard password == confirm else {
            confirmField.setError("비밀번호가 일치하지 않아요"); return
        }
        guard agreeService && agreePrivacy else {
            showAlert("필수 약관에 동의해주세요.")
            return
        }

        guard DataStore.shared.createUser(nickname: nickname, email: email, password: password) != nil else {
            emailField.setError("가입에 실패했어요. 다시 시도해주세요"); return
        }

        SessionManager.login(email: email.lowercased())
        setWindowRoot(AppNavigationController(rootViewController: HomeViewController()))
    }

    private func showAlert(_ message: String) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Term Row

final class TermRow: UIView {

    private let accentColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
    private var checked = false
    private let checkButton = UIButton(type: .system)
    private let titleLabel = UILabel()

    var onToggle: ((Bool) -> Void)?
    var onChevron: (() -> Void)?

    init(title: String, bold: Bool, showChevron: Bool) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        checkButton.translatesAutoresizingMaskIntoConstraints = false
        checkButton.addTarget(self, action: #selector(toggle), for: .touchUpInside)
        updateCheckImage()

        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: bold ? 15 : 14, weight: bold ? .bold : .medium)
        titleLabel.textColor = bold ? .black : UIColor(white: 0.3, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(checkButton)
        addSubview(titleLabel)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 44),
            checkButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            checkButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkButton.widthAnchor.constraint(equalToConstant: 26),
            checkButton.heightAnchor.constraint(equalToConstant: 26),
            titleLabel.leadingAnchor.constraint(equalTo: checkButton.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        if showChevron {
            let chevron = UIButton(type: .system)
            var config = UIButton.Configuration.plain()
            config.title = "보기"
            config.image = UIImage(systemName: "chevron.right",
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
            config.imagePlacement = .trailing
            config.imagePadding = 2
            config.contentInsets = .zero
            var attr = AttributeContainer()
            attr.font = UIFont.systemFont(ofSize: 12, weight: .regular)
            config.attributedTitle = AttributedString("보기", attributes: attr)
            config.baseForegroundColor = UIColor(white: 0.6, alpha: 1.0)
            chevron.configuration = config
            chevron.translatesAutoresizingMaskIntoConstraints = false
            chevron.addTarget(self, action: #selector(chevronTapped), for: .touchUpInside)
            addSubview(chevron)
            NSLayoutConstraint.activate([
                chevron.trailingAnchor.constraint(equalTo: trailingAnchor),
                chevron.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setChecked(_ on: Bool) {
        checked = on
        updateCheckImage()
    }

    private func updateCheckImage() {
        let symbol = checked ? "checkmark.circle.fill" : "circle"
        let img = UIImage(systemName: symbol,
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
        checkButton.setImage(img, for: .normal)
        checkButton.tintColor = checked ? accentColor : UIColor(white: 0.78, alpha: 1.0)
    }

    @objc private func toggle() {
        checked.toggle()
        updateCheckImage()
        onToggle?(checked)
    }

    @objc private func chevronTapped() { onChevron?() }
}
