//
//  MonthViewController.swift
//  IOS_Clandar
//

import UIKit
import EventKit

final class MonthViewController: UIViewController {
    var onSelectDate: ((Date) -> Void)?

    private let eventStore: EKEventStore
    private let calendar: Calendar
    private var displayedMonth: Date
    private var selectedDate: Date
    private var gridDates: [Date?] = []
    private var daysWithEvents: Set<Date> = []

    private let monthLabel = UILabel()
    private let weekdaySymbolsView = UIStackView()
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.dataSource = self
        view.delegate = self
        view.backgroundColor = .clear
        view.isScrollEnabled = false
        view.register(MonthDayCell.self, forCellWithReuseIdentifier: MonthDayCell.reuseIdentifier)
        return view
    }()

    init(initialDate: Date, calendar: Calendar = .current, eventStore: EKEventStore = EKEventStore()) {
        self.calendar = calendar
        self.selectedDate = initialDate
        self.displayedMonth = calendar.dateInterval(of: .month, for: initialDate)?.start ?? initialDate
        self.eventStore = eventStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupHeader()
        setupWeekdaySymbols()
        setupCollectionView()
        requestAccessAndReload()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        (collectionView.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize = cellSize()
        collectionView.collectionViewLayout.invalidateLayout()
    }

    func show(date: Date) {
        selectedDate = date
        let newMonth = calendar.dateInterval(of: .month, for: date)?.start ?? date
        if !calendar.isDate(newMonth, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = newMonth
            reloadEventsAndGrid()
        } else {
            collectionView.reloadData()
        }
    }

    // MARK: - UI Setup

    private func setupHeader() {
        let previousButton = UIButton(type: .system)
        previousButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        previousButton.addTarget(self, action: #selector(previousMonthTapped), for: .touchUpInside)

        let nextButton = UIButton(type: .system)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextMonthTapped), for: .touchUpInside)

        monthLabel.font = UIFont.boldSystemFont(ofSize: 20)
        monthLabel.textAlignment = .center

        let headerStack = UIStackView(arrangedSubviews: [previousButton, monthLabel, nextButton])
        headerStack.axis = .horizontal
        headerStack.distribution = .equalSpacing
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(headerStack)

        NSLayoutConstraint.activate([
            headerStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            headerStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            headerStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
    }

    private func setupWeekdaySymbols() {
        weekdaySymbolsView.axis = .horizontal
        weekdaySymbolsView.distribution = .fillEqually
        weekdaySymbolsView.translatesAutoresizingMaskIntoConstraints = false

        for symbol in orderedShortWeekdaySymbols() {
            let label = UILabel()
            label.text = symbol
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 13)
            label.textColor = .secondaryLabel
            weekdaySymbolsView.addArrangedSubview(label)
        }

        view.addSubview(weekdaySymbolsView)

        NSLayoutConstraint.activate([
            weekdaySymbolsView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 52),
            weekdaySymbolsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            weekdaySymbolsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            weekdaySymbolsView.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    private func setupCollectionView() {
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: weekdaySymbolsView.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func cellSize() -> CGSize {
        let width = collectionView.bounds.width / 7
        let rows = CGFloat(gridDates.count / 7 == 0 ? 6 : gridDates.count / 7)
        let height = rows > 0 ? min(width, collectionView.bounds.height / rows) : width
        return CGSize(width: width, height: height)
    }

    // MARK: - Data

    private func requestAccessAndReload() {
        let completion: EKEventStoreRequestAccessCompletionHandler = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.reloadEventsAndGrid()
            }
        }

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents(completion: completion)
        } else {
            eventStore.requestAccess(to: .event, completion: completion)
        }
    }

    private func reloadEventsAndGrid() {
        computeGridDates()
        fetchDaysWithEvents()
        updateMonthLabel()
        collectionView.reloadData()
        view.setNeedsLayout()
    }

    private func computeGridDates() {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            gridDates = []
            return
        }

        let firstOfMonth = monthInterval.start
        let firstWeekdayOfMonth = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlankCount = (firstWeekdayOfMonth - calendar.firstWeekday + 7) % 7

        let daysInMonth = calendar.range(of: .day, in: .month, for: firstOfMonth)?.count ?? 30

        var dates: [Date?] = Array(repeating: nil, count: leadingBlankCount)
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: firstOfMonth) {
                dates.append(date)
            }
        }
        while dates.count % 7 != 0 {
            dates.append(nil)
        }

        gridDates = dates
    }

    private func fetchDaysWithEvents() {
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else {
            daysWithEvents = []
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: monthInterval.start, end: monthInterval.end, calendars: nil)
        let events = eventStore.events(matching: predicate)
        daysWithEvents = Set(events.map { calendar.startOfDay(for: $0.startDate) })
    }

    private func updateMonthLabel() {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "LLLL yyyy"
        monthLabel.text = formatter.string(from: displayedMonth).capitalized
    }

    private func orderedShortWeekdaySymbols() -> [String] {
        let symbols = calendar.shortWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    // MARK: - Actions

    @objc private func previousMonthTapped() {
        guard let newMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
        displayedMonth = newMonth
        reloadEventsAndGrid()
    }

    @objc private func nextMonthTapped() {
        guard let newMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
        displayedMonth = newMonth
        reloadEventsAndGrid()
    }
}

extension MonthViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        gridDates.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MonthDayCell.reuseIdentifier, for: indexPath)
        guard let dayCell = cell as? MonthDayCell else { return cell }

        guard let date = gridDates[indexPath.item] else {
            dayCell.configure(day: nil, isToday: false, isSelected: false, isInCurrentMonth: false, hasEvents: false)
            return dayCell
        }

        let day = calendar.component(.day, from: date)
        dayCell.configure(
            day: day,
            isToday: calendar.isDateInToday(date),
            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
            isInCurrentMonth: calendar.isDate(date, equalTo: displayedMonth, toGranularity: .month),
            hasEvents: daysWithEvents.contains(calendar.startOfDay(for: date))
        )
        return dayCell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let date = gridDates[indexPath.item] else { return }
        selectedDate = date
        collectionView.reloadData()
        onSelectDate?(date)
    }
}
