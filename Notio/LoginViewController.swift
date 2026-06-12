//
//  LoginViewController.swift
//  Notio
//
//  로컬 로그인 화면. (이메일/비밀번호 유효성 검사 후 SwiftData에서 인증)
//

import UIKit

class LoginViewController: UIViewController {

    private let accentColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
    private var autoLoginOn = true

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

    private let browseButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("둘러보기", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        b.setTitleColor(UIColor(white: 0.4, alpha: 1.0), for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
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

    private let mascot: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "nio-hi"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.numberOfLines = 0
        l.textAlignment = .center
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 2
        para.alignment = .center
        l.attributedText = NSAttributedString(string: "다시 만나서\n반가워요", attributes: [
            .font: UIFont.systemFont(ofSize: 26, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: para
        ])
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emailField = LabeledField(title: "이메일", placeholder: "study@notio.io",
                                          keyboard: .emailAddress)
    private let passwordField = LabeledField(title: "비밀번호", placeholder: "비밀번호 입력", secure: true)

    private let loginButton = LoginViewController.makePillButton(title: "로그인", filled: true)

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        emailField.textField.text = "study@notio.io"
        passwordField.addRevealToggle()
        setupLayout()

        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        browseButton.addTarget(self, action: #selector(browseTapped), for: .touchUpInside)
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

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
        view.addSubview(browseButton)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(mascot)
        contentStack.setCustomSpacing(8, after: mascot)
        contentStack.addArrangedSubview(titleLabel)
        contentStack.setCustomSpacing(28, after: titleLabel)
        contentStack.addArrangedSubview(emailField)
        contentStack.addArrangedSubview(passwordField)
        contentStack.addArrangedSubview(makeOptionsRow())
        contentStack.setCustomSpacing(20, after: contentStack.arrangedSubviews.last!)
        contentStack.addArrangedSubview(loginButton)
        contentStack.setCustomSpacing(24, after: loginButton)
        contentStack.addArrangedSubview(makeSignupRow())

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            browseButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            browseButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            scrollView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 4),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 28),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -28),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -24),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -56),

            mascot.heightAnchor.constraint(equalToConstant: 120),
            loginButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func makeOptionsRow() -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let auto = UIButton(type: .system)
        updateAutoLoginButton(auto)
        auto.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        auto.contentHorizontalAlignment = .leading
        auto.translatesAutoresizingMaskIntoConstraints = false
        auto.addTarget(self, action: #selector(toggleAutoLogin(_:)), for: .touchUpInside)

        let forgot = UIButton(type: .system)
        forgot.setTitle("비밀번호 찾기", for: .normal)
        forgot.setTitleColor(accentColor, for: .normal)
        forgot.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        forgot.translatesAutoresizingMaskIntoConstraints = false
        forgot.addTarget(self, action: #selector(comingSoon), for: .touchUpInside)

        row.addSubview(auto)
        row.addSubview(forgot)
        NSLayoutConstraint.activate([
            row.heightAnchor.constraint(equalToConstant: 24),
            auto.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            auto.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            forgot.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            forgot.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])
        return row
    }

    private func updateAutoLoginButton(_ button: UIButton) {
        let symbol = autoLoginOn ? "checkmark.square.fill" : "square"
        let img = UIImage(systemName: symbol,
                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold))
        button.setImage(img, for: .normal)
        button.setTitle("  자동 로그인", for: .normal)
        button.tintColor = autoLoginOn ? accentColor : UIColor(white: 0.6, alpha: 1.0)
        button.setTitleColor(UIColor(white: 0.4, alpha: 1.0), for: .normal)
    }

    private func makeSignupRow() -> UIView {
        let button = UIButton(type: .system)
        let text = NSMutableAttributedString(string: "Notio가 처음이세요?  ", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor(white: 0.4, alpha: 1.0)
        ])
        text.append(NSAttributedString(string: "회원가입", attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: accentColor
        ]))
        button.setAttributedTitle(text, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(signupTapped), for: .touchUpInside)
        return button
    }

    static func makePillButton(title: String, filled: Bool) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)
        b.layer.cornerRadius = 16
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    // MARK: - Actions

    @objc private func backTapped() {
        setWindowRoot(OnboardingViewController())
    }

    @objc private func browseTapped() {
        // 둘러보기: 데모 계정으로 로그인해 샘플 데이터를 탐색.
        SessionManager.login(email: "study@notio.io")
        goHome()
    }

    @objc private func toggleAutoLogin(_ sender: UIButton) {
        autoLoginOn.toggle()
        updateAutoLoginButton(sender)
    }

    @objc private func comingSoon() {
        let alert = UIAlertController(title: nil, message: "준비 중인 기능이에요.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }

    @objc private func signupTapped() {
        navigationController?.pushViewController(SignupViewController(), animated: true)
    }

    @objc private func loginTapped() {
        view.endEditing(true)
        emailField.setError(nil)
        passwordField.setError(nil)

        let email = emailField.text
        let password = passwordField.text

        guard !email.isEmpty else { emailField.setError("이메일을 입력해주세요"); return }
        guard Validator.isValidEmail(email) else {
            emailField.setError("올바른 이메일 형식이 아니에요"); return
        }
        guard !password.isEmpty else { passwordField.setError("비밀번호를 입력해주세요"); return }

        guard DataStore.shared.authenticate(email: email, password: password) != nil else {
            passwordField.setError("이메일 또는 비밀번호가 올바르지 않아요")
            shake(loginButton)
            return
        }

        SessionManager.login(email: email.lowercased())
        goHome()
    }

    private func goHome() {
        setWindowRoot(AppNavigationController(rootViewController: HomeViewController()))
    }

    private func shake(_ v: UIView) {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.values = [-8, 8, -6, 6, -3, 3, 0]
        anim.duration = 0.4
        v.layer.add(anim, forKey: "shake")
    }
}
