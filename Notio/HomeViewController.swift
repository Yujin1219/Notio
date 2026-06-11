//
//  HomeViewController.swift
//  Notio
//

import UIKit

class HomeViewController: UIViewController {

    // MARK: - Data

    private let categories = NoteCategory.allCases

    private let notes: [NoteItem] = [
        NoteItem(title: "운영체제론 3강", keywords: "프로세스 스케줄링, 동기화, 세마포어", status: .completed, progress: 1.0),
        NoteItem(title: "데이터베이스 2강", keywords: "정규화, ER 다이어그램, SQL 기초", status: .completed, progress: 0.7),
        NoteItem(title: "알고리즘 5강", keywords: "동적 프로그래밍, 분할정복", status: .inProgress, progress: 0.5),
        NoteItem(title: "네트워크 개론 1강", keywords: "OSI 7계층, TCP/IP 모델", status: .completed, progress: 1.0),
    ]

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
        view.backgroundColor = UIColor(red: 0.96, green: 0.95, blue: 0.93, alpha: 1.0)
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

    private let searchPlaceholder: UILabel = {
        let label = UILabel()
        label.text = "강의 노트 검색"
        label.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        label.textColor = .gray
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

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

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.97, green: 0.96, blue: 0.94, alpha: 1.0)
        setupLayout()
        setupCategories()
        setupTableView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableHeight()
    }

    // MARK: - Setup

    private func setupLayout() {
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        contentView.addSubview(titleLabel)
        contentView.addSubview(menuButton)
        contentView.addSubview(searchBar)
        searchBar.addSubview(searchIcon)
        searchBar.addSubview(searchPlaceholder)
        contentView.addSubview(categoryScrollView)
        categoryScrollView.addSubview(categoryStackView)
        contentView.addSubview(streakView)
        contentView.addSubview(tableView)

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

            searchPlaceholder.centerYAnchor.constraint(equalTo: searchBar.centerYAnchor),
            searchPlaceholder.leadingAnchor.constraint(equalTo: searchIcon.trailingAnchor, constant: 8),

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
            button.backgroundColor = UIColor(red: 0.93, green: 0.92, blue: 0.89, alpha: 1.0)
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

    @objc private func categoryTapped(_ sender: UIButton) {
        selectedCategoryIndex = sender.tag
        for case let button as UIButton in categoryStackView.arrangedSubviews {
            updateCategoryButton(button, isSelected: button.tag == selectedCategoryIndex)
        }
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

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 110
    }
}
