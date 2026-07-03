//
//  WeekViewController.swift
//  IOS_Clandar
//

import UIKit
import EventKit

final class WeekViewController: UIViewController {
    var onSelectDate: ((Date) -> Void)?

    private let eventStore: EKEventStore
    private let calendar: Calendar
    private var weekStart: Date
    private var eventsByDay: [Date: [EKEvent]] = [:]

    private let weekRangeLabel = UILabel()
    private let headerStack = UIStackView()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    init(initialDate: Date, calendar: Calendar = .current, eventStore: EKEventStore = EKEventStore()) {
        self.calendar = calendar
        self.weekStart = calendar.dateInterval(of: .weekOfYear, for: initialDate)?.start ?? initialDate
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
        setupTableView()
        requestAccessAndReload()
    }

    func show(date: Date) {
        let newWeekStart = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        guard !calendar.isDate(newWeekStart, equalTo: weekStart, toGranularity: .weekOfYear) else { return }
        weekStart = newWeekStart
        reload()
    }

    // MARK: - UI Setup

    private func setupHeader() {
        let previousButton = UIButton(type: .system)
        previousButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        previousButton.addTarget(self, action: #selector(previousWeekTapped), for: .touchUpInside)

        let nextButton = UIButton(type: .system)
        nextButton.setImage(UIImage(systemName: "chevron.right"), for: .normal)
        nextButton.addTarget(self, action: #selector(nextWeekTapped), for: .touchUpInside)

        weekRangeLabel.font = UIFont.boldSystemFont(ofSize: 17)
        weekRangeLabel.textAlignment = .center

        headerStack.addArrangedSubview(previousButton)
        headerStack.addArrangedSubview(weekRangeLabel)
        headerStack.addArrangedSubview(nextButton)
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

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "EventCell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Data

    private func requestAccessAndReload() {
        let completion: EKEventStoreRequestAccessCompletionHandler = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.reload()
            }
        }

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents(completion: completion)
        } else {
            eventStore.requestAccess(to: .event, completion: completion)
        }
    }

    private func reload() {
        updateWeekRangeLabel()
        fetchEventsForWeek()
        tableView.reloadData()
    }

    private func fetchEventsForWeek() {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else {
            eventsByDay = [:]
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: weekInterval.start, end: weekInterval.end, calendars: nil)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }

        var grouped: [Date: [EKEvent]] = [:]
        for event in events {
            let day = calendar.startOfDay(for: event.startDate)
            grouped[day, default: []].append(event)
        }
        eventsByDay = grouped
    }

    private func updateWeekRangeLabel() {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: weekStart) else { return }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "MMM d"
        let end = calendar.date(byAdding: .day, value: -1, to: weekInterval.end) ?? weekInterval.end
        weekRangeLabel.text = "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: end))"
    }

    private func weekDates() -> [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    // MARK: - Actions

    @objc private func previousWeekTapped() {
        guard let newWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart) else { return }
        weekStart = newWeekStart
        reload()
    }

    @objc private func nextWeekTapped() {
        guard let newWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { return }
        weekStart = newWeekStart
        reload()
    }
}

extension WeekViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        7
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        max(events(forSection: section).count, 1)
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let date = weekDates()[section]
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.dateFormat = "EEEE, MMM d"
        let title = formatter.string(from: date)
        return calendar.isDateInToday(date) ? "\(title) (Today)" : title
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell", for: indexPath)
        let dayEvents = events(forSection: indexPath.section)

        var configuration = cell.defaultContentConfiguration()
        if dayEvents.isEmpty {
            configuration.text = "No events"
            configuration.textProperties.color = .secondaryLabel
            configuration.secondaryText = nil
            cell.selectionStyle = .none
        } else {
            let event = dayEvents[indexPath.row]
            configuration.text = event.title
            configuration.secondaryText = event.isAllDay ? "All-day" : Self.timeFormatter.string(from: event.startDate)
            cell.selectionStyle = .default
        }
        cell.contentConfiguration = configuration
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let date = weekDates()[indexPath.section]
        onSelectDate?(date)
    }

    private func events(forSection section: Int) -> [EKEvent] {
        eventsByDay[weekDates()[section]] ?? []
    }
}
