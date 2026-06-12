//
//  SourceTextViewController.swift
//  Notio
//
//  업로드한 파일에서 추출한 원문 텍스트를 보여주는 화면.
//

import UIKit

class SourceTextViewController: UIViewController {

    private let noteTitle: String
    private let sourceText: String

    init(noteTitle: String, sourceText: String) {
        self.noteTitle = noteTitle
        self.sourceText = sourceText
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
        l.text = "원문 텍스트"
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .black
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        l.textColor = .gray
        l.lineBreakMode = .byTruncatingTail
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let card: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 18
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.04
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 8
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let textView: UITextView = {
        let tv = UITextView()
        tv.isEditable = false
        tv.backgroundColor = .clear
        tv.textColor = UIColor(white: 0.20, alpha: 1.0)
        tv.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        tv.textContainerInset = UIEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        tv.showsVerticalScrollIndicator = true
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)

        let charCount = sourceText.count
        subtitleLabel.text = "\(noteTitle) · \(charCount)자"

        if charCount == 0 {
            textView.text = "추출된 텍스트가 없어요.\n스캔된 이미지 PDF라면 텍스트가 추출되지 않을 수 있어요."
            textView.textColor = .gray
        } else {
            let para = NSMutableParagraphStyle()
            para.lineSpacing = 5
            textView.attributedText = NSAttributedString(string: sourceText, attributes: [
                .font: UIFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: UIColor(white: 0.20, alpha: 1.0),
                .paragraphStyle: para
            ])
        }

        setupLayout()
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    private func setupLayout() {
        view.addSubview(backButton)
        view.addSubview(navTitleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(card)
        card.addSubview(textView)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            navTitleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            navTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),

            card.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            card.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            card.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),

            textView.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),
            textView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 4),
            textView.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -4),
            textView.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4),
        ])
    }

    @objc private func backTapped() { goBack() }
}
