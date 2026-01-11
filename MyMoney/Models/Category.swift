//
//  Category.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Category {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var createdAt: Date

    // Usage tracking per spese ricorrenti
    var usageCount: Int
    var lastUsedDate: Date?

    var categoryGroup: CategoryGroup?
    var defaultAccount: Account?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .cascade, inverse: \Budget.category)
    var budgets: [Budget]?

    init(
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#007AFF",
        categoryGroup: CategoryGroup? = nil,
        defaultAccount: Account? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.createdAt = Date()
        self.usageCount = 0
        self.lastUsedDate = nil
        self.categoryGroup = categoryGroup
        self.defaultAccount = defaultAccount
        self.transactions = []
        self.budgets = []
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    // MARK: - Usage Tracking

    /// Incrementa il contatore di utilizzo quando viene usata la categoria
    func recordUsage() {
        usageCount += 1
        lastUsedDate = Date()
    }

    /// Conta quante volte è stata usata negli ultimi N giorni
    func usageInLastDays(_ days: Int) -> Int {
        guard let transactions = transactions else { return 0 }

        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: now) else {
            return 0
        }

        return transactions.filter { transaction in
            transaction.status == .executed &&
            transaction.date >= startDate &&
            transaction.date <= now
        }.count
    }

    /// Verifica se la categoria è "ricorrente" (usata più di 3 volte negli ultimi 30 giorni)
    var isRecurring: Bool {
        return usageInLastDays(30) >= 3
    }

    /// Budget attivo per questa categoria
    var activeBudget: Budget? {
        budgets?.first { $0.isActive && ($0.endDate == nil || $0.endDate! >= Date()) }
    }
}
