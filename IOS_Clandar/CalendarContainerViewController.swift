//
//  CalendarContainerViewController.swift
//  IOS_Clandar
//

import UIKit

final class CalendarContainerViewController: UIViewController {
    private enum Mode: Int {
        case day
        case week
        case month
    }

    private let dayViewController = CalendarViewController()
    private lazy var weekViewController: WeekViewController = {
        let controller = WeekViewController(initialDate: selectedDate)
        controller.onSelectDate = { [weak self] date in self?.selectDateAndShowDay(date) }
        return controller
    }()
    private lazy var monthViewController: MonthViewController = {
        let controller = MonthViewController(initialDate: selectedDate)
        controller.onSelectDate = { [weak self] date in self?.selectDateAndShowDay(date) }
        return controller
    }()

    private var selectedDate = Date()
    private var currentChild: UIViewController?

    private let segmentedControl = UISegmentedControl(items: ["Day", "Week", "Month"])

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Calendar"

        segmentedControl.selectedSegmentIndex = Mode.day.rawValue
        segmentedControl.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        navigationItem.titleView = segmentedControl

        setChild(dayViewController, animated: false)
    }

    @objc private func modeChanged() {
        guard let mode = Mode(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        switch mode {
        case .day:
            dayViewController.move(to: selectedDate)
            setChild(dayViewController, animated: true)
        case .week:
            weekViewController.show(date: selectedDate)
            setChild(weekViewController, animated: true)
        case .month:
            monthViewController.show(date: selectedDate)
            setChild(monthViewController, animated: true)
        }
    }

    private func selectDateAndShowDay(_ date: Date) {
        selectedDate = date
        segmentedControl.selectedSegmentIndex = Mode.day.rawValue
        dayViewController.move(to: date)
        setChild(dayViewController, animated: true)
    }

    // MARK: - Container transitions

    private func setChild(_ child: UIViewController, animated: Bool) {
        guard currentChild !== child else { return }
        let previousChild = currentChild

        addChild(child)
        child.view.frame = view.bounds
        child.view.translatesAutoresizingMaskIntoConstraints = false
        child.view.alpha = animated ? 0 : 1
        view.addSubview(child.view)
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        previousChild?.willMove(toParent: nil)
        previousChild?.beginAppearanceTransition(false, animated: animated)
        child.beginAppearanceTransition(true, animated: animated)

        let finish = {
            child.endAppearanceTransition()
            previousChild?.endAppearanceTransition()
            previousChild?.view.removeFromSuperview()
            previousChild?.removeFromParent()
            child.didMove(toParent: self)
        }

        if animated {
            UIView.animate(withDuration: 0.2, animations: {
                child.view.alpha = 1
                previousChild?.view.alpha = 0
            }, completion: { _ in
                previousChild?.view.alpha = 1
                finish()
            })
        } else {
            finish()
        }

        currentChild = child
    }
}
