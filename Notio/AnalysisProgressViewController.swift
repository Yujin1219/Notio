//
//  AnalysisProgressViewController.swift
//  Notio
//

import UIKit

class AnalysisProgressViewController: UIViewController {

    enum Stage: Int, CaseIterable {
        case extraction
        case summary
        case quiz

        var title: String {
            switch self {
            case .extraction: return "텍스트 추출"
            case .summary: return "핵심 요약 생성"
            case .quiz: return "키워드 정리"
            }
        }
    }

    enum StageStatus { case waiting, inProgress, done }

    private let draft: NoteDraft
    private let noteTitle: String
    private var pageCount: Int { draft.pageCount }
    private var charCount: Int { draft.extractedText.count }

    /// 분석이 모두 끝났을 때 호출된다. (노트 제목, 생성된 콘텐츠)
    var onComplete: ((String, GeneratedContent) -> Void)?

    private var statuses: [StageStatus] = [.inProgress, .waiting, .waiting]
    private var details: [String] = ["PDF 분석 중...", "대기 중", "대기 중"]
    private var hasFinishedAll = false
    private var analysisTask: Task<Void, Never>?

    init(draft: NoteDraft) {
        self.draft = draft
        let trimmed = draft.noteTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            self.noteTitle = (draft.fileName as NSString).deletingPathExtension
        } else {
            self.noteTitle = trimmed
        }
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

    private let mascotImageView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "nio-snooze"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.text = "AI가 노트를\n만들고 있어요"
        l.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        l.textColor = .black
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "평균 15-30초 정도 걸려요. 잠시만 기다려주세요."
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = .gray
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let stageCard: UIView = {
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

    private let rowStack: UIStackView = {
        let s = UIStackView()
        s.axis = .vertical
        s.spacing = 0
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()

    private var stageRows: [StageRowView] = []

    private let totalProgressLabel: UILabel = {
        let l = UILabel()
        l.text = "전체 진행률"
        l.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        l.textColor = .darkGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressPercentLabel: UILabel = {
        let l = UILabel()
        l.text = "0%"
        l.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        l.textColor = .black
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let progressBar: UIProgressView = {
        let bar = UIProgressView(progressViewStyle: .default)
        bar.progressTintColor = UIColor(red: 0.18, green: 0.15, blue: 0.22, alpha: 1.0)
        bar.trackTintColor = UIColor(white: 0.85, alpha: 1.0)
        bar.layer.cornerRadius = 2
        bar.clipsToBounds = true
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()

    private let nioCard: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.6)
        v.layer.cornerRadius = 18
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let nioAvatar: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "nio-hi"))
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let nioNameLabel: UILabel = {
        let l = UILabel()
        l.text = "Nio"
        l.font = UIFont.italicSystemFont(ofSize: 13)
        l.textColor = .darkGray
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let nioMessageLabel: UILabel = {
        let l = UILabel()
        l.text = "기다리는 동안 다른 화면을 봐도 괜찮아요."
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = .darkGray
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let cancelButton: UIButton = {
        let b = UIButton(type: .system)
        b.setTitle("분석 취소", for: .normal)
        b.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        b.setTitleColor(.darkGray, for: .normal)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let backButton: UIButton = {
        let b = UIButton(type: .system)
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.left",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold))
        config.title = "취소"
        config.imagePadding = 2
        config.contentInsets = .zero
        var attr = AttributeContainer()
        attr.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        config.attributedTitle = AttributedString("취소", attributes: attr)
        b.configuration = config
        b.tintColor = .black
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        setupLayout()
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        details[0] = "PDF \(pageCount)페이지 분석 중..."
        refresh()
        startAnalysis()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
    }

    // MARK: - Layout

    private func setupLayout() {
        view.addSubview(mascotImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(stageCard)
        stageCard.addSubview(rowStack)
        view.addSubview(totalProgressLabel)
        view.addSubview(progressPercentLabel)
        view.addSubview(progressBar)
        view.addSubview(nioCard)
        nioCard.addSubview(nioAvatar)
        nioCard.addSubview(nioNameLabel)
        nioCard.addSubview(nioMessageLabel)
        view.addSubview(cancelButton)
        view.addSubview(backButton)

        for stage in Stage.allCases {
            let row = StageRowView(stage: stage)
            rowStack.addArrangedSubview(row)
            stageRows.append(row)
            if stage != .quiz {
                let sep = UIView()
                sep.backgroundColor = UIColor(white: 0.92, alpha: 1.0)
                sep.translatesAutoresizingMaskIntoConstraints = false
                sep.heightAnchor.constraint(equalToConstant: 1).isActive = true
                rowStack.addArrangedSubview(sep)
            }
        }

        NSLayoutConstraint.activate([
            mascotImageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            mascotImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mascotImageView.widthAnchor.constraint(equalToConstant: 180),
            mascotImageView.heightAnchor.constraint(equalToConstant: 180),

            titleLabel.topAnchor.constraint(equalTo: mascotImageView.bottomAnchor, constant: 4),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            stageCard.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 22),
            stageCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stageCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            rowStack.topAnchor.constraint(equalTo: stageCard.topAnchor, constant: 12),
            rowStack.leadingAnchor.constraint(equalTo: stageCard.leadingAnchor, constant: 16),
            rowStack.trailingAnchor.constraint(equalTo: stageCard.trailingAnchor, constant: -16),
            rowStack.bottomAnchor.constraint(equalTo: stageCard.bottomAnchor, constant: -12),

            totalProgressLabel.topAnchor.constraint(equalTo: stageCard.bottomAnchor, constant: 18),
            totalProgressLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            progressPercentLabel.centerYAnchor.constraint(equalTo: totalProgressLabel.centerYAnchor),
            progressPercentLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            progressBar.topAnchor.constraint(equalTo: totalProgressLabel.bottomAnchor, constant: 8),
            progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            progressBar.heightAnchor.constraint(equalToConstant: 4),

            nioCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nioCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            nioCard.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -16),

            nioAvatar.leadingAnchor.constraint(equalTo: nioCard.leadingAnchor, constant: 12),
            nioAvatar.centerYAnchor.constraint(equalTo: nioCard.centerYAnchor),
            nioAvatar.widthAnchor.constraint(equalToConstant: 40),
            nioAvatar.heightAnchor.constraint(equalToConstant: 40),

            nioNameLabel.topAnchor.constraint(equalTo: nioCard.topAnchor, constant: 14),
            nioNameLabel.leadingAnchor.constraint(equalTo: nioAvatar.trailingAnchor, constant: 10),

            nioMessageLabel.topAnchor.constraint(equalTo: nioNameLabel.bottomAnchor, constant: 2),
            nioMessageLabel.leadingAnchor.constraint(equalTo: nioAvatar.trailingAnchor, constant: 10),
            nioMessageLabel.trailingAnchor.constraint(equalTo: nioCard.trailingAnchor, constant: -12),
            nioMessageLabel.bottomAnchor.constraint(equalTo: nioCard.bottomAnchor, constant: -14),

            cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            backButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    // MARK: - State update

    private func refresh() {
        for (i, row) in stageRows.enumerated() {
            row.update(status: statuses[i], detail: details[i])
        }
        let weights = statuses.map { st -> Float in
            switch st {
            case .done: return 1.0
            case .inProgress: return 0.5
            case .waiting: return 0.0
            }
        }
        let progress = weights.reduce(0, +) / Float(Stage.allCases.count)
        progressBar.setProgress(progress, animated: true)
        progressPercentLabel.text = "\(Int(progress * 100))%"
    }

    // MARK: - Analysis

    private func startAnalysis() {
        analysisTask = Task { @MainActor in await self.runAnalysis() }
    }

    @MainActor
    private func runAnalysis() async {
        // 1단계: 텍스트 추출 (PDFKit이 이미 뽑아둔 결과 표시)
        statuses = [.inProgress, .waiting, .waiting]
        details[0] = "PDF \(pageCount)페이지 분석 중..."
        refresh()
        try? await Task.sleep(nanoseconds: 300_000_000)
        statuses[0] = .done
        details[0] = "PDF \(pageCount)페이지 · \(formattedCharCount())자"

        // 2~3단계: Gemini로 요약·문제 생성 (한 번의 호출)
        statuses[1] = .inProgress
        details[1] = "AI가 요약·문제 생성 중..."
        refresh()

        do {
            // 노트 생성 시엔 요약·키워드만 만든다. (문제는 "새 문제 만들기"로 별도 생성)
            let content = try await GeminiService.shared.generate(
                title: noteTitle,
                pdfData: draft.pdfData,
                extractedText: draft.extractedText,
                includeQuizzes: false)

            if Task.isCancelled { return }
            statuses[1] = .done
            details[1] = "요약 \(content.summaries.count)개 생성 완료"
            statuses[2] = .done
            details[2] = "키워드 \(content.keywords.count)개 정리 완료"
            hasFinishedAll = true
            refresh()

            try? await Task.sleep(nanoseconds: 500_000_000)
            // 사용자가 입력한 제목이 있으면 그대로 사용하고, 비워뒀을 때만 Gemini 생성 제목 사용.
            let userTitle = draft.noteTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let finalTitle: String
            if !userTitle.isEmpty {
                finalTitle = userTitle
            } else {
                let generated = content.title.trimmingCharacters(in: .whitespacesAndNewlines)
                finalTitle = generated.isEmpty ? noteTitle : generated
            }
            onComplete?(finalTitle, content)
        } catch {
            if Task.isCancelled || error is CancellationError { return }   // 취소는 조용히 종료
            handleError(error)
        }
    }

    @MainActor
    private func handleError(_ error: Error) {
        statuses[1] = .waiting
        details[1] = "분석 실패"
        refresh()

        let message = (error as? GeminiError)?.errorDescription ?? error.localizedDescription
        let alert = UIAlertController(title: "분석 실패", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { [weak self] _ in
            self?.startAnalysis()
        })
        alert.addAction(UIAlertAction(title: "닫기", style: .cancel) { [weak self] _ in
            self?.presentingViewController?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func formattedCharCount() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: charCount)) ?? "\(charCount)"
    }

    @objc private func cancelTapped() {
        analysisTask?.cancel()
        presentingViewController?.dismiss(animated: true)
    }
}

// MARK: - Stage Row

final class StageRowView: UIView {

    private let iconCircle = UIView()
    private let iconImageView = UIImageView()
    private let spinner: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = UIColor(red: 0.42, green: 0.36, blue: 0.62, alpha: 1.0)
        ai.hidesWhenStopped = true
        ai.translatesAutoresizingMaskIntoConstraints = false
        return ai
    }()
    private let titleLabel = UILabel()
    private let detailLabel = UILabel()
    private let badge = PaddedLabel()

    init(stage: AnalysisProgressViewController.Stage) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        titleLabel.text = stage.title
        titleLabel.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = UIFont.systemFont(ofSize: 12, weight: .regular)
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        iconCircle.translatesAutoresizingMaskIntoConstraints = false
        iconCircle.layer.cornerRadius = 14
        iconCircle.clipsToBounds = true

        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.contentMode = .center
        iconImageView.tintColor = .white

        badge.text = "진행 중"
        badge.font = UIFont.systemFont(ofSize: 11, weight: .semibold)
        badge.textColor = UIColor(red: 0.42, green: 0.36, blue: 0.62, alpha: 1.0)
        badge.backgroundColor = UIColor(red: 0.90, green: 0.86, blue: 0.95, alpha: 1.0)
        badge.layer.cornerRadius = 11
        badge.layer.masksToBounds = true
        badge.padding = UIEdgeInsets(top: 3, left: 10, bottom: 3, right: 10)
        badge.isHidden = true
        badge.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconCircle)
        iconCircle.addSubview(iconImageView)
        addSubview(spinner)
        addSubview(titleLabel)
        addSubview(detailLabel)
        addSubview(badge)

        NSLayoutConstraint.activate([
            iconCircle.leadingAnchor.constraint(equalTo: leadingAnchor),
            iconCircle.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconCircle.widthAnchor.constraint(equalToConstant: 28),
            iconCircle.heightAnchor.constraint(equalToConstant: 28),

            iconImageView.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            spinner.centerXAnchor.constraint(equalTo: iconCircle.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: iconCircle.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 12),

            detailLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            detailLabel.leadingAnchor.constraint(equalTo: iconCircle.trailingAnchor, constant: 12),
            detailLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),

            badge.trailingAnchor.constraint(equalTo: trailingAnchor),
            badge.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(status: AnalysisProgressViewController.StageStatus, detail: String) {
        detailLabel.text = detail
        switch status {
        case .waiting:
            iconCircle.isHidden = false
            iconCircle.backgroundColor = .clear
            iconCircle.layer.borderWidth = 1.5
            iconCircle.layer.borderColor = UIColor(white: 0.85, alpha: 1.0).cgColor
            iconImageView.image = nil
            spinner.stopAnimating()
            titleLabel.textColor = UIColor(white: 0.6, alpha: 1.0)
            detailLabel.textColor = UIColor(white: 0.7, alpha: 1.0)
            badge.isHidden = true
        case .inProgress:
            iconCircle.isHidden = true
            iconImageView.image = nil
            spinner.startAnimating()
            titleLabel.textColor = .black
            detailLabel.textColor = .gray
            badge.isHidden = false
        case .done:
            iconCircle.isHidden = false
            iconCircle.backgroundColor = UIColor(red: 0.36, green: 0.66, blue: 0.42, alpha: 1.0)
            iconCircle.layer.borderWidth = 0
            iconImageView.image = UIImage(systemName: "checkmark",
                                          withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold))
            spinner.stopAnimating()
            titleLabel.textColor = .black
            detailLabel.textColor = .gray
            badge.isHidden = true
        }
    }
}

// MARK: - Padded Label

final class PaddedLabel: UILabel {
    var padding: UIEdgeInsets = .zero {
        didSet { invalidateIntrinsicContentSize() }
    }
    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: padding))
    }
    override var intrinsicContentSize: CGSize {
        let s = super.intrinsicContentSize
        return CGSize(width: s.width + padding.left + padding.right,
                      height: s.height + padding.top + padding.bottom)
    }
}
