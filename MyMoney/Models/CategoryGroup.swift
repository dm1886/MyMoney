//
//  CategoryGroup.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftData
import SwiftUI

// Enum che definisce l'applicabilità di un gruppo di categorie
enum TransactionTypeScope: String, Codable, CaseIterable {
    case all = "Tutte"                      // Visibile ovunque
    case expenseOnly = "Solo Uscite"
    case incomeOnly = "Solo Entrate"
    case transferOnly = "Solo Trasferimenti"
    case expenseAndIncome = "Uscite ed Entrate"
    case none = "Nessuna"                   // Non visibile (disabilitato)

    var icon: String {
        switch self {
        case .all: return "circle.grid.3x3.fill"
        case .expenseOnly: return "arrow.down.circle.fill"
        case .incomeOnly: return "arrow.up.circle.fill"
        case .transferOnly: return "arrow.left.arrow.right.circle.fill"
        case .expenseAndIncome: return "arrow.up.arrow.down.circle.fill"
        case .none: return "nosign"
        }
    }

    // Verifica se questo scope è applicabile al tipo di transazione specificato
    func isApplicable(to transactionType: TransactionType) -> Bool {
        switch self {
        case .all:
            return true
        case .expenseOnly:
            return transactionType == .expense
        case .incomeOnly:
            return transactionType == .income
        case .transferOnly:
            return transactionType == .transfer
        case .expenseAndIncome:
            return transactionType == .expense || transactionType == .income
        case .none:
            return false
        }
    }
}

@Model
final class CategoryGroup {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date

    // Store as string to handle legacy data migration
    private var applicabilityRaw: String = TransactionTypeScope.all.rawValue

    // Computed property with safe fallback
    var applicability: TransactionTypeScope {
        get {
            TransactionTypeScope(rawValue: applicabilityRaw) ?? .all
        }
        set {
            applicabilityRaw = newValue.rawValue
        }
    }

    @Relationship(deleteRule: .cascade, inverse: \Category.categoryGroup)
    var categories: [Category]?

    init(
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#007AFF",
        sortOrder: Int = 0,
        applicability: TransactionTypeScope = .all
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.applicabilityRaw = applicability.rawValue
        self.categories = []
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var sortedCategories: [Category] {
        categories?.sorted { $0.name < $1.name } ?? []
    }
}
