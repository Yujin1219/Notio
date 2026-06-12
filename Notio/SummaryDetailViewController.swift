//
//  SummaryDetailViewController.swift
//  Notio
//

import UIKit

enum DetailSection {
    case definition(text: String, bolded: [String])
    case numberedList(items: [String])
    case table(columns: [String], rows: [[String]])
}

struct DetailPage {
    let sections: [(title: String, content: DetailSection)]
}

class SummaryDetailViewController: UIViewController {

    private let items: [SummaryItem]
    private let pages: [DetailPage]
    private var currentIndex: Int

    init(items: [SummaryItem], pages: [DetailPage], startIndex: Int) {
        self.items = items
        self.pages = pages
        self.currentIndex = startIndex
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
        l.text = "자세히 보기"
        l.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        l.textColor = .black
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let pageCountLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        l.textColor = .darkGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressTrack: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.82, green: 0.78, blue: 0.88, alpha: 0.45)
        v.layer.cornerRadius = 22
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let progressFill: UIView = {
        let v = UIView()
        v.backgroundColor = .white
        v.layer.cornerRadius = 22
        v.layer.shadowColor = UIColor.black.cgColor
        v.layer.shadowOpacity = 0.06
        v.layer.shadowOffset = CGSize(width: 0, height: 2)
        v.layer.shadowRadius = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let romanBadge: UIView = {
        let v = UIView()
        v.layer.cornerRadius = 7
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let romanLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont(name: "Georgia-Italic", size: 14) ?? UIFont.italicSystemFont(ofSize: 14)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressNumberLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 14, weight: .bold)
        l.textColor = .black
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nioDecoration: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "nio-think"))
        iv.contentMode = .scaleAspectFit
        iv.alpha = 0.95
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
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
        s.spacing = 20
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private let prevButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("← 이전", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        b.setTitleColor(.darkGray, for: .normal)
        b.backgroundColor = UIColor.white.withAlphaComponent(0.85)
        b.layer.cornerRadius = 27
        b.contentEdgeInsets = UIEdgeInsets(top: 14, left: 22, bottom: 14, right: 22)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let nextButton: UIButton = {
        let b = UIButton(type: .system)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        b.setTitleColor(.white, for: .normal)
        b.backgroundColor = UIColor(red: 0.13, green: 0.12, blue: 0.18, alpha: 1.0)
        b.layer.cornerRadius = 27
        b.contentEdgeInsets = UIEdgeInsets(top: 14, left: 22, bottom: 14, right: 22)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private var progressFillWidthConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        setupLayout()
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        prevButton.addTarget(self, action: #selector(prevTapped), for: .touchUpInside)
        nextButton.addTarget(self, action: #selector(nextTapped), for: .touchUpInside)
        applyPage(animated: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(backButton)
        view.addSubview(navTitleLabel)
        view.addSubview(pageCountLabel)
        view.addSubview(progressTrack)
        progressTrack.addSubview(progressFill)
        progressFill.addSubview(romanBadge)
        romanBadge.addSubview(romanLabel)
        progressFill.addSubview(progressNumberLabel)
        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(nioDecoration)
        view.addSubview(prevButton)
        view.addSubview(nextButton)

        let fillWidth = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: 0.33)
        fillWidth.isActive = true
        progressFillWidthConstraint = fillWidth

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 36),
            backButton.heightAnchor.constraint(equalToConstant: 36),

            navTitleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            navTitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            pageCountLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            pageCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            progressTrack.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 12),
            progressTrack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            progressTrack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            progressTrack.heightAnchor.constraint(equalToConstant: 44),

            progressFill.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressFill.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressFill.bottomAnchor.constraint(equalTo: progressTrack.bottomAnchor),

            romanBadge.leadingAnchor.constraint(equalTo: progressFill.leadingAnchor, constant: 12),
            romanBadge.centerYAnchor.constraint(equalTo: progressFill.centerYAnchor),
            romanBadge.widthAnchor.constraint(equalToConstant: 26),
            romanBadge.heightAnchor.constraint(equalToConstant: 26),

            romanLabel.centerXAnchor.constraint(equalTo: romanBadge.centerXAnchor),
            romanLabel.centerYAnchor.constraint(equalTo: romanBadge.centerYAnchor),

            progressNumberLabel.leadingAnchor.constraint(equalTo: romanBadge.trailingAnchor, constant: 10),
            progressNumberLabel.centerYAnchor.constraint(equalTo: progressFill.centerYAnchor),

            nioDecoration.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 6),
            nioDecoration.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            nioDecoration.widthAnchor.constraint(equalToConstant: 56),
            nioDecoration.heightAnchor.constraint(equalToConstant: 56),

            scrollView.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: prevButton.topAnchor, constant: -10),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 4),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -10),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40),

            prevButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            prevButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            prevButton.heightAnchor.constraint(equalToConstant: 54),

            nextButton.leadingAnchor.constraint(equalTo: prevButton.trailingAnchor, constant: 10),
            nextButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nextButton.centerYAnchor.constraint(equalTo: prevButton.centerYAnchor),
            nextButton.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    // MARK: - Apply current page

    private func applyPage(animated: Bool) {
        guard currentIndex < items.count, currentIndex < pages.count else { return }
        let item = items[currentIndex]
        let page = pages[currentIndex]
        let total = items.count

        pageCountLabel.text = "\(currentIndex + 1)/\(total)"
        romanBadge.backgroundColor = item.iconBackground
        romanLabel.text = item.roman
        romanLabel.textColor = item.accentColor
        progressNumberLabel.text = "핵심 \(item.number)"

        let fraction = max(0.18, CGFloat(currentIndex + 1) / CGFloat(total))
        progressFillWidthConstraint?.isActive = false
        let newConstraint = progressFill.widthAnchor.constraint(equalTo: progressTrack.widthAnchor, multiplier: fraction)
        newConstraint.isActive = true
        progressFillWidthConstraint = newConstraint

        prevButton.isHidden = (currentIndex == 0)
        if currentIndex < total - 1 {
            nextButton.setTitle("다음: \(items[currentIndex + 1].title) →", for: .normal)
        } else {
            nextButton.setTitle("완료 ✓", for: .normal)
        }

        contentStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for section in page.sections {
            contentStack.addArrangedSubview(
                makeSectionView(title: section.title,
                                content: section.content,
                                accentColor: item.accentColor,
                                iconBg: item.iconBackground)
            )
        }

        if animated {
            UIView.animate(withDuration: 0.3) {
                self.view.layoutIfNeeded()
            }
        }
    }

    // MARK: - Section builders

    private func makeSectionView(title: String, content: DetailSection,
                                 accentColor: UIColor, iconBg: UIColor) -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.42, alpha: 1.0)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let card = UIView()
        card.backgroundColor = .white
        card.layer.cornerRadius = 16
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.04
        card.layer.shadowOffset = CGSize(width: 0, height: 2)
        card.layer.shadowRadius = 8
        card.translatesAutoresizingMaskIntoConstraints = false

        let inner: UIView
        switch content {
        case .definition(let text, let bolded):
            inner = makeDefinitionView(text: text, bolded: bolded)
        case .numberedList(let items):
            inner = makeNumberedList(items: items, accentColor: accentColor, iconBg: iconBg)
        case .table(let columns, let rows):
            inner = makeTable(columns: columns, rows: rows, iconBg: iconBg)
        }
        inner.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(inner)

        container.addSubview(titleLabel)
        container.addSubview(card)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),

            card.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            inner.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            inner.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            inner.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            inner.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return container
    }

    private func makeDefinitionView(text: String, bolded: [String]) -> UIView {
        let label = UILabel()
        label.numberOfLines = 0
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        let attributed = NSMutableAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 15, weight: .regular),
            .foregroundColor: UIColor(white: 0.22, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ])
        for substring in bolded {
            let range = (text as NSString).range(of: substring)
            if range.location != NSNotFound {
                attributed.addAttributes([
                    .font: UIFont.systemFont(ofSize: 15, weight: .bold),
                    .foregroundColor: UIColor.black
                ], range: range)
            }
        }
        label.attributedText = attributed
        return label
    }

    private func makeNumberedList(items: [String], accentColor: UIColor, iconBg: UIColor) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 14
        for (i, text) in items.enumerated() {
            stack.addArrangedSubview(makeNumberedRow(number: i + 1, text: text,
                                                     accentColor: accentColor, iconBg: iconBg))
        }
        return stack
    }

    private func makeNumberedRow(number: Int, text: String,
                                 accentColor: UIColor, iconBg: UIColor) -> UIView {
        let container = UIView()
        let circle = UIView()
        circle.backgroundColor = iconBg
        circle.layer.cornerRadius = 11
        circle.translatesAutoresizingMaskIntoConstraints = false

        let numberLabel = UILabel()
        numberLabel.text = "\(number)"
        numberLabel.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        numberLabel.textColor = accentColor
        numberLabel.textAlignment = .center
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        circle.addSubview(numberLabel)

        let textLabel = UILabel()
        textLabel.numberOfLines = 0
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        textLabel.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 14, weight: .regular),
            .foregroundColor: UIColor(white: 0.22, alpha: 1.0),
            .paragraphStyle: paragraphStyle
        ])
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(circle)
        container.addSubview(textLabel)

        NSLayoutConstraint.activate([
            circle.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
            circle.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            circle.widthAnchor.constraint(equalToConstant: 22),
            circle.heightAnchor.constraint(equalToConstant: 22),

            numberLabel.centerXAnchor.constraint(equalTo: circle.centerXAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: circle.centerYAnchor),

            textLabel.topAnchor.constraint(equalTo: container.topAnchor),
            textLabel.leadingAnchor.constraint(equalTo: circle.trailingAnchor, constant: 12),
            textLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            textLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return container
    }

    private func makeTable(columns: [String], rows: [[String]], iconBg: UIColor) -> UIView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 0

        stack.addArrangedSubview(makeTableRow(values: columns, isHeader: true, iconBg: iconBg))

        for row in rows {
            let sep = UIView()
            sep.backgroundColor = UIColor(white: 0.92, alpha: 1.0)
            sep.translatesAutoresizingMaskIntoConstraints = false
            sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
            stack.addArrangedSubview(sep)
            stack.addArrangedSubview(makeTableRow(values: row, isHeader: false, iconBg: iconBg))
        }
        return stack
    }

    private func makeTableRow(values: [String], isHeader: Bool, iconBg: UIColor) -> UIView {
        let row = UIView()
        if isHeader {
            row.backgroundColor = iconBg.withAlphaComponent(0.45)
            row.layer.cornerRadius = 10
            row.clipsToBounds = true
        }

        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.distribution = .fillEqually
        hStack.spacing = 8
        hStack.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(hStack)

        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: row.topAnchor, constant: isHeader ? 12 : 14),
            hStack.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: isHeader ? -12 : -14),
            hStack.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 12),
            hStack.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -12),
        ])

        for v in values {
            let label = UILabel()
            label.text = v
            label.font = UIFont.systemFont(ofSize: 14, weight: isHeader ? .semibold : .medium)
            label.textColor = isHeader ? UIColor(white: 0.30, alpha: 1.0) : UIColor(white: 0.22, alpha: 1.0)
            label.numberOfLines = 0
            hStack.addArrangedSubview(label)
        }
        return row
    }

    // MARK: - Actions

    @objc private func backTapped() { goBack() }

    @objc private func prevTapped() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
        applyPage(animated: true)
        scrollView.setContentOffset(.zero, animated: false)
    }

    @objc private func nextTapped() {
        if currentIndex < items.count - 1 {
            currentIndex += 1
            applyPage(animated: true)
            scrollView.setContentOffset(.zero, animated: false)
        } else {
            goBack()
        }
    }
}
