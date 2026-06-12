//
//  NoteCardCell.swift
//  Notio
//

import UIKit

class NoteCardCell: UITableViewCell {

    static let identifier = "NoteCardCell"

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 16
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(red: 0.88, green: 0.87, blue: 0.84, alpha: 1.0).cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let keywordsLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let statusBadge: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        label.textAlignment = .center
        label.layer.cornerRadius = 12
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let progressBarBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.90, green: 0.89, blue: 0.93, alpha: 1.0)
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let progressBarFill: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(red: 0.45, green: 0.45, blue: 0.42, alpha: 1.0)
        view.layer.cornerRadius = 2
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private var progressWidthConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }

    private func setupCell() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(cardView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(keywordsLabel)
        cardView.addSubview(statusBadge)
        cardView.addSubview(progressBarBackground)
        progressBarBackground.addSubview(progressBarFill)

        let progressWidth = progressBarFill.widthAnchor.constraint(equalToConstant: 0)
        progressWidthConstraint = progressWidth

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: statusBadge.leadingAnchor, constant: -8),

            statusBadge.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusBadge.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            statusBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),
            statusBadge.heightAnchor.constraint(equalToConstant: 24),

            keywordsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            keywordsLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            keywordsLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),

            progressBarBackground.topAnchor.constraint(equalTo: keywordsLabel.bottomAnchor, constant: 14),
            progressBarBackground.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 18),
            progressBarBackground.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -18),
            progressBarBackground.heightAnchor.constraint(equalToConstant: 4),
            progressBarBackground.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18),

            progressBarFill.topAnchor.constraint(equalTo: progressBarBackground.topAnchor),
            progressBarFill.leadingAnchor.constraint(equalTo: progressBarBackground.leadingAnchor),
            progressBarFill.heightAnchor.constraint(equalTo: progressBarBackground.heightAnchor),
            progressWidth,
        ])
    }

    func configure(with item: Note) {
        titleLabel.text = item.title
        keywordsLabel.text = item.keywords

        statusBadge.text = item.status.rawValue

        switch item.status {
        case .completed:
            statusBadge.backgroundColor = UIColor(red: 0.85, green: 0.88, blue: 0.82, alpha: 1.0)
            statusBadge.textColor = UIColor(red: 0.30, green: 0.38, blue: 0.25, alpha: 1.0)
        case .inProgress:
            statusBadge.backgroundColor = UIColor(red: 0.96, green: 0.93, blue: 0.82, alpha: 1.0)
            statusBadge.textColor = UIColor(red: 0.55, green: 0.48, blue: 0.25, alpha: 1.0)
        }

        progressWidthConstraint?.isActive = false
        progressWidthConstraint = progressBarFill.widthAnchor.constraint(
            equalTo: progressBarBackground.widthAnchor,
            multiplier: item.progress
        )
        progressWidthConstraint?.isActive = true
    }
}
