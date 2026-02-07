//
//  DefaultDataManager.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import Foundation
import SwiftData

class DefaultDataManager {
    static func createDefaultCategories(context: ModelContext) {
        let foodGroup = CategoryGroup(name: "Cibo & Bevande", icon: "fork.knife", colorHex: "#FF9500", sortOrder: 1)
        let transportGroup = CategoryGroup(name: "Trasporti", icon: "car.fill", colorHex: "#007AFF", sortOrder: 2)
        let homeGroup = CategoryGroup(name: "Casa", icon: "house.fill", colorHex: "#34C759", sortOrder: 3)
        let shoppingGroup = CategoryGroup(name: "Shopping", icon: "bag.fill", colorHex: "#FF2D55", sortOrder: 4)
        let travelGroup = CategoryGroup(name: "Viaggi", icon: "airplane", colorHex: "#5856D6", sortOrder: 5)
        let incomeGroup = CategoryGroup(name: "Entrate", icon: "dollarsign.circle.fill", colorHex: "#34C759", sortOrder: 6)
        let financeGroup = CategoryGroup(name: "Spese Finanziarie", icon: "banknote.fill", colorHex: "#FF3B30", sortOrder: 7)

        context.insert(foodGroup)
        context.insert(transportGroup)
        context.insert(homeGroup)
        context.insert(shoppingGroup)
        context.insert(travelGroup)
        context.insert(incomeGroup)
        context.insert(financeGroup)

        let foodCategories = [
            Category(name: "Caffè", icon: "cup.and.saucer.fill", colorHex: "#8B4513", categoryGroup: foodGroup),
            Category(name: "Supermercato", icon: "cart.fill", colorHex: "#FF9500", categoryGroup: foodGroup),
            Category(name: "Ristorante", icon: "fork.knife", colorHex: "#FF3B30", categoryGroup: foodGroup),
            Category(name: "Bar", icon: "wineglass.fill", colorHex: "#AF52DE", categoryGroup: foodGroup),
            Category(name: "Fast Food", icon: "takeoutbag.and.cup.and.straw.fill", colorHex: "#FF9500", categoryGroup: foodGroup)
        ]

        let transportCategories = [
            Category(name: "Taxi", icon: "car.fill", colorHex: "#FFD700", categoryGroup: transportGroup),
            Category(name: "Benzina", icon: "fuelpump.fill", colorHex: "#FF3B30", categoryGroup: transportGroup),
            Category(name: "Parcheggio", icon: "parkingsign.circle.fill", colorHex: "#007AFF", categoryGroup: transportGroup),
            Category(name: "Trasporto Pubblico", icon: "bus.fill", colorHex: "#34C759", categoryGroup: transportGroup),
            Category(name: "Pedaggio", icon: "road.lanes", colorHex: "#FF9500", categoryGroup: transportGroup)
        ]

        let homeCategories = [
            Category(name: "Affitto", icon: "house.fill", colorHex: "#5856D6", categoryGroup: homeGroup),
            Category(name: "Utenze", icon: "bolt.fill", colorHex: "#FF9500", categoryGroup: homeGroup),
            Category(name: "Internet", icon: "wifi", colorHex: "#007AFF", categoryGroup: homeGroup),
            Category(name: "Manutenzione", icon: "wrench.and.screwdriver.fill", colorHex: "#8E8E93", categoryGroup: homeGroup)
        ]

        let shoppingCategories = [
            Category(name: "Abbigliamento", icon: "tshirt.fill", colorHex: "#FF2D55", categoryGroup: shoppingGroup),
            Category(name: "Elettronica", icon: "laptopcomputer", colorHex: "#007AFF", categoryGroup: shoppingGroup),
            Category(name: "Libri", icon: "book.fill", colorHex: "#FF9500", categoryGroup: shoppingGroup),
            Category(name: "Farmacia", icon: "cross.case.fill", colorHex: "#FF3B30", categoryGroup: shoppingGroup),
            Category(name: "Sport", icon: "figure.run", colorHex: "#34C759", categoryGroup: shoppingGroup)
        ]

        let travelCategories = [
            Category(name: "Volo", icon: "airplane.departure", colorHex: "#5856D6", categoryGroup: travelGroup),
            Category(name: "Hotel", icon: "bed.double.fill", colorHex: "#FF9500", categoryGroup: travelGroup),
            Category(name: "Vacanza", icon: "beach.umbrella.fill", colorHex: "#00C7BE", categoryGroup: travelGroup)
        ]

        let incomeCategories = [
            Category(name: "Stipendio", icon: "banknote.fill", colorHex: "#34C759", categoryGroup: incomeGroup),
            Category(name: "Freelance", icon: "laptopcomputer", colorHex: "#007AFF", categoryGroup: incomeGroup),
            Category(name: "Regalo", icon: "gift.fill", colorHex: "#FF2D55", categoryGroup: incomeGroup),
            Category(name: "Investimenti", icon: "chart.line.uptrend.xyaxis", colorHex: "#5856D6", categoryGroup: incomeGroup)
        ]
        
        let financeCategories = [
            Category(name: "Interessi Passivi", icon: "percent", colorHex: "#FF3B30", categoryGroup: financeGroup),
            Category(name: "Commissioni Bancarie", icon: "building.columns.fill", colorHex: "#FF9500", categoryGroup: financeGroup)
        ]

        for category in foodCategories + transportCategories + homeCategories + shoppingCategories + travelCategories + incomeCategories + financeCategories {
            context.insert(category)
        }
    }
}
