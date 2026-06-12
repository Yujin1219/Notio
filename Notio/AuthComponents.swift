//
//  AuthComponents.swift
//  Notio
//
//  로그인/회원가입 화면에서 공통으로 쓰는 입력 컴포넌트.
//

import UIKit

/// 좌우 여백이 있는 텍스트필드.
final class PaddedTextField: UITextField {
    var textInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)

    override func textRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insetWithAccessory)
    }
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insetWithAccessory)
    }
    override func placeholderRect(forBounds bounds: CGRect) -> CGRect {
        bounds.inset(by: insetWithAccessory)
    }

    /// 우측 뷰(눈 아이콘 등)를 안쪽으로 조금 당겨 배치한다.
    override func rightViewRect(forBounds bounds: CGRect) -> CGRect {
        var rect = super.rightViewRect(forBounds: bounds)
        rect.origin.x -= 10
        return rect
    }

    private var insetWithAccessory: UIEdgeInsets {
        var inset = textInset
        if let rv = rightView, rightViewMode != .never {
            inset.right += rv.bounds.width + 8
        }
        return inset
    }
}

/// 제목 라벨 + 입력 필드 + (선택) 우측 액세서리 + 에러 라벨을 묶은 뷰.
final class LabeledField: UIView {

    private let accentColor = UIColor(red: 0.49, green: 0.36, blue: 0.78, alpha: 1.0)
    private let normalBorder = UIColor(white: 0.90, alpha: 1.0)
    private let errorColor = UIColor(red: 0.82, green: 0.40, blue: 0.38, alpha: 1.0)
    private let okColor = UIColor(red: 0.30, green: 0.62, blue: 0.40, alpha: 1.0)

    let textField = PaddedTextField()

    private let titleLabel = UILabel()
    private let accessoryLabel = UILabel()
    private let errorLabel = UILabel()

    var text: String { textField.text?.trimmingCharacters(in: .whitespaces) ?? "" }

    init(title: String, placeholder: String, secure: Bool = false,
         keyboard: UIKeyboardType = .default) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.35, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        textField.placeholder = placeholder
        textField.isSecureTextEntry = secure
        textField.keyboardType = keyboard
        textField.autocapitalizationType = .none
        textField.autocorrectionType = .no
        textField.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        textField.backgroundColor = .white
        textField.layer.cornerRadius = 12
        textField.layer.borderWidth = 1.0
        textField.layer.borderColor = normalBorder.cgColor
        textField.translatesAutoresizingMaskIntoConstraints = false

        accessoryLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        accessoryLabel.translatesAutoresizingMaskIntoConstraints = false
        accessoryLabel.isHidden = true

        errorLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        errorLabel.textColor = errorColor
        errorLabel.numberOfLines = 0
        errorLabel.translatesAutoresizingMaskIntoConstraints = false
        errorLabel.isHidden = true

        addSubview(titleLabel)
        addSubview(accessoryLabel)
        addSubview(textField)
        addSubview(errorLabel)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),

            accessoryLabel.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            accessoryLabel.trailingAnchor.constraint(equalTo: trailingAnchor),

            textField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: trailingAnchor),
            textField.heightAnchor.constraint(equalToConstant: 50),

            errorLabel.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 5),
            errorLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            errorLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            errorLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 에러 표시. nil이면 정상 상태로.
    func setError(_ message: String?) {
        if let message, !message.isEmpty {
            errorLabel.text = message
            errorLabel.isHidden = false
            textField.layer.borderColor = errorColor.cgColor
        } else {
            errorLabel.isHidden = true
            textField.layer.borderColor = normalBorder.cgColor
        }
    }

    /// 우측 상단 보조 라벨 (예: "✓ 사용 가능"). ok=true면 초록, false면 빨강.
    func setAccessory(_ text: String?, ok: Bool) {
        if let text, !text.isEmpty {
            accessoryLabel.text = text
            accessoryLabel.textColor = ok ? okColor : errorColor
            accessoryLabel.isHidden = false
        } else {
            accessoryLabel.isHidden = true
        }
    }

    /// 비밀번호 표시 토글용 우측 눈 모양 버튼을 단다.
    func addRevealToggle() {
        let button = UIButton(type: .system)
        button.tintColor = UIColor(white: 0.55, alpha: 1.0)
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 50)
        button.addTarget(self, action: #selector(toggleReveal(_:)), for: .touchUpInside)
        updateRevealIcon(button)
        textField.rightView = button
        textField.rightViewMode = .always
    }

    @objc private func toggleReveal(_ sender: UIButton) {
        textField.isSecureTextEntry.toggle()
        updateRevealIcon(sender)
    }

    private func updateRevealIcon(_ button: UIButton) {
        // 가려진 상태(secure)면 eye.slash, 보이는 상태면 eye
        let name = textField.isSecureTextEntry ? "eye.slash" : "eye"
        let cfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        button.setImage(UIImage(systemName: name, withConfiguration: cfg), for: .normal)
    }
}
