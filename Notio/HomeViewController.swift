//
//  HomeViewController.swift
//  Notio
//

import UIKit

class HomeViewController: UIViewController {

    // MARK: - Data

    // 탭 순서: 전체 → 즐겨찾기 → 전공 → 교양 → 자격증
    private let categories: [NoteCategory] = [.all, .bookmark, .major, .liberal, .certificate]

    private var notes: [Note] = []

    private var selectedCategoryIndex = 0

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

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Notio"
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private let menuButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        button.setImage(UIImage(systemName: "ellipsis.circle", withConfiguration: config), for: .normal)
        button.tintColor = .darkGray
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let searchBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.35)
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let searchIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        iv.tintColor = .gray
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let searchField: UITextField = {
        let tf = UITextField()
        tf.attributedPlaceholder = NSAttributedString(
            string: "강의 노트 검색",
            attributes: [.foregroundColor: UIColor.gray,
                         .font: UIFont.systemFont(ofSize: 15, weight: .regular)])
        tf.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        tf.textColor = .black
        tf.clearButtonMode = .whileEditing
        tf.returnKeyType = .search
        tf.autocorrectionType = .no
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private var searchQuery: String = ""

    private let categoryScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsHorizontalScrollIndicator = false
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    private let categoryStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    private let streakView: StreakView = {
        let view = StreakView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.separatorStyle = .none
        tv.backgroundColor = .clear
        tv.isScrollEnabled = false
        tv.translatesAutoresizingMaskIntoConstraints = false
        return tv
    }()

    // 노트가 없을 때 표시하는 빈 상태.
    private let emptyIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "doc.text.magnifyingglass"))
        iv.tintColor = UIColor(white: 0.0, alpha: 0.18)
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    private let emptyTitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        l.textColor = UIColor(white: 0.35, alpha: 1.0)
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private let emptySubtitleLabel: UILabel = {
        let l = UILabel()
        l.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        l.textColor = .gray
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()

    private lazy var emptyStateView: UIStackView = {
        let s = UIStackView(arrangedSubviews: [emptyIcon, emptyTitleLabel, emptySubtitleLabel])
        s.axis = .vertical
        s.alignment = .center
        s.spacing = 10
        s.isHidden = true
        s.translatesAutoresizingMaskIntoConstraints = false
        s.setCustomSpacing(16, after: emptyIcon)
        return s
    }()

    private let addButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        button.setImage(UIImage(systemName: "plus", withConfiguration: config), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor(red: 0.22, green: 0.22, blue: 0.20, alpha: 1.0)
        button.layer.cornerRadius = 28
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private var tableHeightConstraint: NSLayoutConstraint?

    private let gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor(red: 0.87, green: 0.84, blue: 0.93, alpha: 1.0).cgColor, // 라벤더
            UIColor(red: 0.95, green: 0.93, blue: 0.89, alpha: 1.0).cgColor  // 베이지
        ]
        layer.locations = [0.0, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        return layer
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.layer.insertSublayer(gradientLayer, at: 0)
        setupLayout()
        setupCategories()
        setupTableView()
        addButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        menuButton.addTarget(self, action: #selector(menuTapped), for: .touchUpInside)
        searchField.addTarget(self, action: #selector(searchChanged(_:)), for: .editingChanged)
        searchField.addTarget(self, action: #selector(searchReturn), for: .editingDidEndOnExit)
        reloadNotes()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // 노트 생성/삭제 후 돌아왔을 때 최신 상태로 갱신.
        reloadNotes()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        gradientLayer.frame = view.bounds
        updateTableHeight()
    }

    private func reloadNotes() {
        let all = DataStore.shared.fetchNotes()
        let selected = categories[selectedCategoryIndex]
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if !query.isEmpty {
            // 검색 중에는 카테고리 무시하고 전체에서 제목·키워드로 찾는다.
            notes = all.filter {
                $0.title.lowercased().contains(query) || $0.keywords.lowercased().contains(query)
            }
        } else {
            switch selected {
            case .all:        notes = all
            case .bookmark:   notes = all.filter { $0.isFavorite }
            default:          notes = all.filter { $0.category == selected }
            }
        }

        emptyStateView.isHidden = !notes.isEmpty
        if notes.isEmpty {
            if !query.isEmpty {
                emptyTitleLabel.text = "검색 결과가 없어요"
                emptySubtitleLabel.text = "‘\(searchQuery)’와 일치하는 노트가 없어요"
            } else {
                switch selected {
                case .all:
                    emptyTitleLabel.text = "아직 노트가 없어요"
                    emptySubtitleLabel.text = "아래 + 버튼을 눌러 첫 노트를 만들어보세요"
                case .bookmark:
                    emptyTitleLabel.text = "즐겨찾기한 노트가 없어요"
                    emptySubtitleLabel.text = "노트 요약 화면의 ‘저장’을 누르면 여기에 모여요"
                default:
                    emptyTitleLabel.text = "이 분류에 노트가 없어요"
                    emptySubtitleLabel.text = "‘\(selected.rawValue)’ 분류의 노트가 아직 없어요"
                }
            }
        }

        let stats = DataStore.shared.streakStats()
        streakView.configure(streak: stats.streak, activeWeekdays: stats.activeWeekdays,
                             weekNoteCount: stats.weekNoteCount, weekQuizCount: stats.weekQuizCount)

        tableView.reloadData()
        view.setNeedsLayout()
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(titleLabel)
        contentView.addSubview(menuButton)
        contentView.addSubview(searchBar)
        searchBar.addSubview(searchIcon)
        searchBar.addSubview(searchField)
        contentView.addSubview(categoryScrollView)
        categoryScrollView.addSubview(categoryStackView)
        contentView.addSubview(streakView)
        contentView.addSubview(tableView)
        contentView.addSubview(emptyStateView)

        view.addSubview(addButton)

        NSLayoutConstraint.activate([
            // ScrollView
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),

            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),

            menuButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            menuButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            menuButton.widthAnchor.constraint(equalToConstant: 36),
            menuButton.heightAnchor.constraint(equalToConstant: 36),

            // Search Bar
            searchBar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            searchBar.heightAnchor.constraint(equalToConstant: 44),

            searchIcon.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            searchIcon.leadingAnchor.constraint(equalTo: searchBar.leadingAnchor, constant: 14),
            searchIcon.widthAnchor.constraint(equalToConstant: 18),
            searchIcon.heightAnchor.constraint(equalToConstant: 18),

            searchField.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            searchField.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: searchBar.trailingAnchor, constant: -12),

            // Category ScrollView
            categoryScrollView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 14),
            categoryScrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            categoryScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            categoryScrollView.heightAnchor.constraint(equalToConstant: 36),

            categoryStackView.topAnchor.constraint(equalTo: categoryScrollView.topAnchor),
            categoryStackView.leadingAnchor.constraint(equalTo: categoryScrollView.leadingAnchor, constant: 20),
            categoryStackView.trailingAnchor.constraint(equalTo: categoryScrollView.trailingAnchor, constant: -20),
            categoryStackView.bottomAnchor.constraint(equalTo: categoryScrollView.bottomAnchor),
            categoryStackView.heightAnchor.constraint(equalTo: categoryScrollView.heightAnchor),

            // Streak View
            streakView.topAnchor.constraint(equalTo: categoryScrollView.bottomAnchor, constant: 16),
            streakView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            streakView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            streakView.heightAnchor.constraint(equalToConstant: 100),

            // TableView
            tableView.topAnchor.constraint(equalTo: streakView.bottomAnchor, constant: 12),
            tableView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),

            // Empty state (테이블이 비었을 때 그 자리에 표시)
            emptyStateView.topAnchor.constraint(equalTo: streakView.bottomAnchor, constant: 60),
            emptyStateView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -40),

            emptyIcon.widthAnchor.constraint(equalToConstant: 52),
            emptyIcon.heightAnchor.constraint(equalToConstant: 52),

            // Add Button
            addButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            addButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            addButton.widthAnchor.constraint(equalToConstant: 56),
            addButton.heightAnchor.constraint(equalToConstant: 56),
        ])

        let tableHeight = tableView.heightAnchor.constraint(equalToConstant: 0)
        tableHeightConstraint = tableHeight
        tableHeight.isActive = true
    }

    private func setupCategories() {
        for (index, category) in categories.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(category.rawValue, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            button.layer.cornerRadius = 18
            button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 16, bottom: 6, right: 16)
            button.tag = index
            button.addTarget(self, action: #selector(categoryTapped(_:)), for: .touchUpInside)

            updateCategoryButton(button, isSelected: index == selectedCategoryIndex)
            categoryStackView.addArrangedSubview(button)
        }
    }

    private func setupTableView() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(NoteCardCell.self, forCellReuseIdentifier: NoteCardCell.identifier)
    }

    // MARK: - Helpers

    private func updateCategoryButton(_ button: UIButton, isSelected: Bool) {
        if isSelected {
            button.backgroundColor = UIColor(red: 0.22, green: 0.22, blue: 0.20, alpha: 1.0)
            button.setTitleColor(.white, for: .normal)
        } else {
            button.backgroundColor = UIColor.white.withAlphaComponent(0.45)
            button.setTitleColor(.darkGray, for: .normal)
        }
    }

    private func updateTableHeight() {
        tableView.layoutIfNeeded()
        let height = tableView.contentSize.height
        if tableHeightConstraint?.constant != height {
            tableHeightConstraint?.constant = height
        }
    }

    // MARK: - Actions

    @objc private func searchChanged(_ sender: UITextField) {
        searchQuery = sender.text ?? ""
        reloadNotes()
    }

    @objc private func searchReturn() {
        searchField.resignFirstResponder()
    }

    @objc private func categoryTapped(_ sender: UIButton) {
        selectedCategoryIndex = sender.tag
        for case let button as UIButton in categoryStackView.arrangedSubviews {
            updateCategoryButton(button, isSelected: button.tag == selectedCategoryIndex)
        }
        reloadNotes()
    }

    @objc private func menuTapped() {
        let nickname = DataStore.shared.user(email: SessionManager.currentEmail ?? "")?.nickname
        let sheet = UIAlertController(
            title: nickname.map { "\($0) 님" },
            message: SessionManager.currentEmail,
            preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "로그아웃", style: .destructive) { [weak self] _ in
            SessionManager.logout()
            self?.setWindowRoot(AppNavigationController(rootViewController: LoginViewController()))
        })
        sheet.addAction(UIAlertAction(title: "취소", style: .cancel))
        if let pop = sheet.popoverPresentationController {
            pop.sourceView = menuButton
            pop.sourceRect = menuButton.bounds
        }
        present(sheet, animated: true)
    }

    @objc private func addButtonTapped() {
        let vc = NewNoteViewController()
        vc.onSubmit = { [weak self] draft in
            self?.startAnalysis(draft: draft)
        }
        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(vc, animated: true)
    }

    /// 새 노트 작성 시트가 닫힌 뒤 바로 Gemini 분석을 모달로 띄우고,
    /// 끝나면 결과를 저장한 뒤 요약 화면을 push 한다.
    private func startAnalysis(draft: NoteDraft) {
        let progressVC = AnalysisProgressViewController(draft: draft)
        progressVC.onComplete = { [weak self] title, content in
            guard let self else { return }
            // 생성된 콘텐츠를 JSON으로 저장한다.
            let json = (try? JSONEncoder().encode(content))
                .flatMap { String(data: $0, encoding: .utf8) }
            let keywords = content.keywords.prefix(3).map(\.title).joined(separator: ", ")
            let trimmedSource = draft.extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
            let note = DataStore.shared.addNote(
                title: title,
                keywords: keywords.isEmpty ? "AI 생성 노트" : keywords,
                status: .inProgress, progress: 0.0, category: draft.category,
                contentJSON: json,
                sourceText: trimmedSource.isEmpty ? nil : trimmedSource)

            self.dismiss(animated: true) {
                self.navigationController?.pushViewController(
                    SummaryViewController(note: note, justCreated: true), animated: true)
            }
        }
        present(progressVC, animated: true)
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate

extension HomeViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: NoteCardCell.identifier, for: indexPath) as? NoteCardCell else {
            return UITableViewCell()
        }
        cell.configure(with: notes[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let note = notes[indexPath.row]
        let summary = SummaryViewController(note: note)
        navigationController?.pushViewController(summary, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
        -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "삭제") { [weak self] _, _, done in
            guard let self else { done(false); return }
            let note = self.notes.remove(at: indexPath.row)
            DataStore.shared.delete(note)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            self.view.setNeedsLayout()
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }
}
