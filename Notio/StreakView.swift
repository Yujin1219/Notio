//
//  StreakView.swift
//  Notio
//

import UIKit

class StreakView: UIView {

    private let dayLabels = ["월", "화", "수", "목", "금", "토", "일"]
    private var dotViews: [UIView] = []

    private let activeColor = UIColor(red: 0.30, green: 0.30, blue: 0.28, alpha: 1.0)
    private let inactiveColor = UIColor(red: 0.80, green: 0.78, blue: 0.85, alpha: 1.0)

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
        backgroundColor = UIColor.white.withAlphaComponent(0.4)
        layer.cornerRadius = 16
        clipsToBounds = true

        streakCountLabel.text = "학습 기록을 시작해보세요"
        subtitleLabel.text = "이번 주 노트 0개 · 퀴즈 0문항"

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
        for day in dayLabels {
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
            dot.backgroundColor = inactiveColor
            dotViews.append(dot)

            container.addArrangedSubview(label)
            container.addArrangedSubview(dot)
            daysStackView.addArrangedSubview(container)
        }
    }

    /// 실제 학습 기록으로 갱신한다.
    func configure(streak: Int, activeWeekdays: Set<Int>, weekNoteCount: Int, weekQuizCount: Int) {
        streakCountLabel.text = streak > 0 ? "\(streak)일 연속 학습 중" : "오늘 학습을 시작해보세요"
        subtitleLabel.text = "이번 주 노트 \(weekNoteCount)개 · 퀴즈 \(weekQuizCount)문항"
        for (i, dot) in dotViews.enumerated() {
            dot.backgroundColor = activeWeekdays.contains(i) ? activeColor : inactiveColor
        }
    }
}
