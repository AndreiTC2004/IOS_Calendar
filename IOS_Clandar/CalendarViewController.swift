//
//  CalendarViewController.swift
//  IOS_Clandar
//
//  Created by Andrei Turică on 29.12.2024.
//

import UIKit
import CalendarKit
import EventKit
import EventKitUI

final class CalendarViewController: DayViewController, EKEventEditViewDelegate {
    private var eventStore = EKEventStore()
    private var newsView: NewsView!
    private var newsTimer: Timer?
    private var currentNewsIndex = 0
    private var newsItems: [News] = [] // Inițializăm cu un array gol, va fi populat din API sau mock data

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Calendar"

        requestAccessToCalendar()
        subscribeToNotifications()
        setupNewsView()
        loadNewsData() // Încărcăm datele știrilor
        startNewsTimer()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        newsTimer?.invalidate() // Oprim timer-ul când vizualizarea dispare
    }

    // MARK: - Calendar Setup
    private func requestAccessToCalendar() {
        let completionHandler: EKEventStoreRequestAccessCompletionHandler = { [weak self] granted, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.initializeStore()
                self.subscribeToNotifications()
                self.reloadData()
            }
        }

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents(completion: completionHandler)
        } else {
            eventStore.requestAccess(to: .event, completion: completionHandler)
        }
    }

    private func subscribeToNotifications() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(storeChanged(_:)),
                                               name: .EKEventStoreChanged,
                                               object: eventStore)
    }

    private func initializeStore() {
        eventStore = EKEventStore()
    }

    @objc private func storeChanged(_ notification: Notification) {
        reloadData()
    }

    // MARK: - News Section Setup
    private func setupNewsView() {
        newsView = NewsView()
        newsView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(newsView)

        NSLayoutConstraint.activate([
            newsView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            newsView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            newsView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            newsView.heightAnchor.constraint(equalToConstant: 150) // Înălțimea panoului de știri
        ])
    }

    private func loadNewsData() {
        // Aici poți încărca datele știrilor de la un API sau folosi mock data
        newsItems = [
            News(image: UIImage(named: "news1"), title: "Știre 1", description: "Descriere știre 1"),
            News(image: UIImage(named: "news2"), title: "Știre 2", description: "Descriere știre 2"),
            News(image: UIImage(named: "news3"), title: "Știre 3", description: "Descriere știre 3")
        ]
        updateNewsView() // Afișăm prima știre imediat după încărcare
    }

    private func startNewsTimer() {
        newsTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.updateNewsView()
        }
    }

    private func updateNewsView() {
        guard !newsItems.isEmpty else { return }

        let news = newsItems[currentNewsIndex]
        newsView.configure(with: news)

        // Animația de schimbare a știrii
        UIView.transition(with: newsView, duration: 0.5, options: .transitionCrossDissolve, animations: {
            self.newsView.configure(with: news)
        }, completion: nil)

        // Trecem la următoarea știre
        currentNewsIndex = (currentNewsIndex + 1) % newsItems.count
    }

    // MARK: - CalendarKit Overrides
    override func eventsForDate(_ date: Date) -> [EventDescriptor] {
        let startDate = date
        var oneDayComponents = DateComponents()
        oneDayComponents.day = 1
        let endDate = calendar.date(byAdding: oneDayComponents, to: startDate)!

        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let eventKitEvents = eventStore.events(matching: predicate)
        let calendarKitEvents = eventKitEvents.map(EKWrapper.init)

        return calendarKitEvents
    }

    override func dayViewDidSelectEventView(_ eventView: EventView) {
        guard let ckEvent = eventView.descriptor as? EKWrapper else { return }
        presentDetailViewForEvent(ckEvent.ekEvent)
    }

    private func presentDetailViewForEvent(_ ekEvent: EKEvent) {
        let eventController = EKEventViewController()
        eventController.event = ekEvent
        eventController.allowsCalendarPreview = true
        eventController.allowsEditing = true
        navigationController?.pushViewController(eventController, animated: true)
    }

    override func dayView(dayView: DayView, didLongPressTimelineAt date: Date) {
        endEventEditing()
        let newEKWrapper = createNewEvent(at: date)
        create(event: newEKWrapper, animated: true)
    }

    private func createNewEvent(at date: Date) -> EKWrapper {
        let newEKEvent = EKEvent(eventStore: eventStore)
        newEKEvent.calendar = eventStore.defaultCalendarForNewEvents

        var components = DateComponents()
        components.hour = 1
        let endDate = calendar.date(byAdding: components, to: date)

        newEKEvent.startDate = date
        newEKEvent.endDate = endDate
        newEKEvent.title = "New event"

        let newEKWrapper = EKWrapper(eventKitEvent: newEKEvent)
        newEKWrapper.editedEvent = newEKWrapper
        return newEKWrapper
    }

    override func dayViewDidLongPressEventView(_ eventView: EventView) {
        guard let descriptor = eventView.descriptor as? EKWrapper else { return }
        endEventEditing()
        beginEditing(event: descriptor, animated: true)
    }

    override func dayView(dayView: DayView, didUpdate event: EventDescriptor) {
        guard let editingEvent = event as? EKWrapper else { return }
        if let originalEvent = event.editedEvent {
            editingEvent.commitEditing()

            if originalEvent === editingEvent {
                presentEditingViewForEvent(editingEvent.ekEvent)
            } else {
                try! eventStore.save(editingEvent.ekEvent, span: .thisEvent)
            }
        }
        reloadData()
    }

    private func presentEditingViewForEvent(_ ekEvent: EKEvent) {
        let eventEditViewController = EKEventEditViewController()
        eventEditViewController.event = ekEvent
        eventEditViewController.eventStore = eventStore
        eventEditViewController.editViewDelegate = self
        present(eventEditViewController, animated: true, completion: nil)
    }

    override func dayView(dayView: DayView, didTapTimelineAt date: Date) {
        endEventEditing()
    }

    override func dayViewDidBeginDragging(dayView: DayView) {
        endEventEditing()
    }

    func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
        endEventEditing()
        reloadData()
        controller.dismiss(animated: true, completion: nil)
    }
}
