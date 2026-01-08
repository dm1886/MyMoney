//
//  RecurrenceRule.swift
//  MoneyTracker
//
//  Created on 2026-01-06.
//

import Foundation

// MARK: - Recurrence Unit

enum RecurrenceUnit: String, Codable, CaseIterable {
    case day = "Giorno"
    case month = "Mese"
    case year = "Anno"

    var icon: String {
        switch self {
        case .day:
            return "sun.max.fill"
        case .month:
            return "calendar"
        case .year:
            return "calendar.badge.exclamationmark"
        }
    }

    var pluralName: String {
        switch self {
        case .day:
            return "Giorni"
        case .month:
            return "Mesi"
        case .year:
            return "Anni"
        }
    }
}

// MARK: - Recurrence Rule

struct RecurrenceRule: Codable, Hashable {
    var interval: Int      // 1-365
    var unit: RecurrenceUnit

    init(interval: Int = 1, unit: RecurrenceUnit = .month) {
        self.interval = max(1, min(365, interval))
        self.unit = unit
    }

    var displayString: String {
        if interval == 1 {
            return "Ogni \(unit.rawValue)"
        } else {
            return "Ogni \(interval) \(unit.pluralName)"
        }
    }

    var icon: String {
        unit.icon
    }

    var description: String {
        "Si ripete \(displayString.lowercased())"
    }

    // Calculate next occurrence date from a given date
    func nextOccurrence(from date: Date) -> Date? {
        let calendar = Calendar.current

        switch unit {
        case .day:
            return calendar.date(byAdding: .day, value: interval, to: date)
        case .month:
            return calendar.date(byAdding: .month, value: interval, to: date)
        case .year:
            return calendar.date(byAdding: .year, value: interval, to: date)
        }
    }

    // Calculate multiple future occurrences
    func nextOccurrences(from date: Date, count: Int) -> [Date] {
        var dates: [Date] = []
        var currentDate = date

        for _ in 0..<count {
            if let nextDate = nextOccurrence(from: currentDate) {
                dates.append(nextDate)
                currentDate = nextDate
            } else {
                break
            }
        }

        return dates
    }
}

// Deletion options for recurring transactions
enum RecurringDeletionOption: String, CaseIterable {
    case thisOnly = "Solo Questa"
    case thisAndFuture = "Questa e Future"
    case all = "Tutte"

    var description: String {
        switch self {
        case .thisOnly:
            return "Elimina solo questa transazione"
        case .thisAndFuture:
            return "Elimina questa transazione e tutte le future"
        case .all:
            return "Elimina tutte le transazioni di questa serie, incluse quelle passate"
        }
    }

    var icon: String {
        switch self {
        case .thisOnly:
            return "trash"
        case .thisAndFuture:
            return "trash.circle"
        case .all:
            return "trash.circle.fill"
        }
    }
}

// Edit options for recurring transactions
enum RecurringEditOption: String, CaseIterable {
    case thisOnly = "Solo Questa"
    case thisAndFuture = "Questa e Future"

    var description: String {
        switch self {
        case .thisOnly:
            return "Modifica solo questa transazione"
        case .thisAndFuture:
            return "Modifica questa transazione e tutte le future"
        }
    }
}
