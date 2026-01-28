//
//  WidgetManager.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import Foundation
import SwiftUI

@Observable
class WidgetManager {
    static let shared = WidgetManager()

    private let widgetsKey = "homeWidgets"
    var widgets: [WidgetModel] = []

    private init() {
        loadWidgets()
    }

    func loadWidgets() {
        if let data = UserDefaults.standard.data(forKey: widgetsKey),
           let decoded = try? JSONDecoder().decode([WidgetModel].self, from: data) {
            widgets = decoded.sorted { $0.order < $1.order }
        } else {
            // Default widgets
            widgets = [
                WidgetModel(type: .totalBalance, order: 0),
                WidgetModel(type: .todaySummary, order: 1),
                WidgetModel(type: .dailyTrend, order: 2),
                WidgetModel(type: .budgetProgress, order: 3),
                WidgetModel(type: .quickStats, order: 4)
            ]
            saveWidgets()
        }
    }

    func saveWidgets() {
        if let encoded = try? JSONEncoder().encode(widgets) {
            UserDefaults.standard.set(encoded, forKey: widgetsKey)
        }
    }

    func addWidget(_ widget: WidgetModel) {
        var newWidget = widget
        newWidget.order = widgets.count
        widgets.append(newWidget)
        saveWidgets()
    }

    func removeWidget(_ widget: WidgetModel) {
        widgets.removeAll { $0.id == widget.id }
        // Reorder remaining widgets
        for (index, _) in widgets.enumerated() {
            widgets[index].order = index
        }
        saveWidgets()
    }

    func moveWidget(from source: IndexSet, to destination: Int) {
        widgets.move(fromOffsets: source, toOffset: destination)
        // Update order
        for (index, _) in widgets.enumerated() {
            widgets[index].order = index
        }
        saveWidgets()
    }

    func availableWidgets() -> [WidgetType] {
        let currentTypes = Set(widgets.map { $0.type })
        return WidgetType.allCases.filter { !currentTypes.contains($0) }
    }
}
