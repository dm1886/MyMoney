//
//  CategoryGroup.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class CategoryGroup {
    var id: UUID
    var name: String
    var icon: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Category.categoryGroup)
    var categories: [Category]?

    init(
        name: String,
        icon: String = "folder.fill",
        colorHex: String = "#007AFF",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.categories = []
    }

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var sortedCategories: [Category] {
        categories?.sorted { $0.name < $1.name } ?? []
    }
}
