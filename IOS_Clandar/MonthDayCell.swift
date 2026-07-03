//
//  MonthDayCell.swift
//  IOS_Clandar
//

import UIKit

final class MonthDayCell: UICollectionViewCell {
    static let reuseIdentifier = "MonthDayCell"

    private let dayLabel = UILabel()
    private let eventDot = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        dayLabel.textAlignment = .center
        dayLabel.font = UIFont.systemFont(ofSize: 16)
        dayLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(dayLabel)

        eventDot.backgroundColor = .systemBlue
        eventDot.layer.cornerRadius = 3
        eventDot.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(eventDot)

        NSLayoutConstraint.activate([
            dayLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            dayLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -4),
            dayLabel.widthAnchor.constraint(equalToConstant: 32),
            dayLabel.heightAnchor.constraint(equalToConstant: 32),

            eventDot.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            eventDot.topAnchor.constraint(equalTo: dayLabel.bottomAnchor, constant: 2),
            eventDot.widthAnchor.constraint(equalToConstant: 6),
            eventDot.heightAnchor.constraint(equalToConstant: 6)
        ])
    }

    func configure(day: Int?, isToday: Bool, isSelected: Bool, isInCurrentMonth: Bool, hasEvents: Bool) {
        guard let day else {
            dayLabel.text = nil
            dayLabel.backgroundColor = .clear
            eventDot.isHidden = true
            isUserInteractionEnabled = false
            return
        }

        isUserInteractionEnabled = true
        dayLabel.text = "\(day)"
        dayLabel.layer.cornerRadius = 16
        dayLabel.layer.masksToBounds = true
        eventDot.isHidden = !hasEvents

        if isToday {
            dayLabel.backgroundColor = .systemBlue
            dayLabel.textColor = .white
        } else if isSelected {
            dayLabel.backgroundColor = .systemGray4
            dayLabel.textColor = .label
        } else {
            dayLabel.backgroundColor = .clear
            dayLabel.textColor = isInCurrentMonth ? .label : .tertiaryLabel
        }
    }
}
