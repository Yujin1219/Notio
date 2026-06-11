//
//  StreakView.swift
//  Notio
//

import UIKit

class StreakView: UIView {

    private let dayLabels = ["월", "화", "수", "목", "금", "토", "일"]
    // 이번 주 학습한 요일 (0 = 월, 1 = 화, ...)
    private let activeDays: Set<Int> = [0, 1, 2, 3, 4]

    private let streakCountLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        label.textColor = .darkGray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let daysStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 6
        stack.alignment = .center
        stack.distribution = .equalSpacing
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.92, alpha: 1.0)
        layer.cornerRadius = 16
        clipsToBounds = true

        streakCountLabel.text = "5일 연속 학습 중"
        subtitleLabel.text = "이번 주 노트 3개 · 퀴즈 12문항"

        addSubview(streakCountLabel)
        addSubview(subtitleLabel)
        addSubview(daysStackView)

        setupDayDots()

        NSLayoutConstraint.activate([
            streakCountLabel.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            streakCountLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            subtitleLabel.topAnchor.constraint(equalTo: streakCountLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            daysStackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            daysStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
        ])
    }

    private func setupDayDots() {
        for (index, day) in dayLabels.enumerated() {
            let container = UIStackView()
            container.axis = .vertical
            container.alignment = .center
            container.spacing = 4

            let label = UILabel()
            label.text = day
            label.font = UIFont.systemFont(ofSize: 11, weight: .medium)
            label.textColor = .gray
            label.textAlignment = .center

            let dot = UIView()
            dot.translatesAutoresizingMaskIntoConstraints = false
            dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
            dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
            dot.layer.cornerRadius = 4

            if activeDays.contains(index) {
                dot.backgroundColor = UIColor(red: 0.30, green: 0.30, blue: 0.28, alpha: 1.0)
            } else {
                dot.backgroundColor = UIColor(red: 0.82, green: 0.80, blue: 0.76, alpha: 1.0)
            }

            container.addArrangedSubview(label)
            container.addArrangedSubview(dot)
            daysStackView.addArrangedSubview(container)
        }
    }
}
