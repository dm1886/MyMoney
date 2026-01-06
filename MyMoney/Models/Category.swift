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

    var categoryGroup: CategoryGroup?
    var defaultAccount: Account?

    @Relationship(deleteRule: .nullify, inverse: \Transaction.category)
    var transactions: [Transaction]?

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
        self.categoryGroup = categoryGroup
        self.defaultAccount = defaultAccount
        self.transactions = []
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }
}
