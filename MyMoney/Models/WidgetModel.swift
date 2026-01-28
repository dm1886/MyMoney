//
//  WidgetModel.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import Foundation
import SwiftUI

enum WidgetType: String, Codable, CaseIterable, Identifiable {
    case totalBalance = "Saldo Totale"
    case todaySummary = "Riepilogo Oggi"
    case budgetProgress = "Progresso Budget"
    case spendingByCategory = "Spese per Categoria"
    case incomeVsExpenses = "Entrate vs Uscite"
    case netWorthTrend = "Andamento Patrimonio"
    case topCategories = "Top Categorie"
    case savingsRate = "Tasso Risparmio"
    case dailyAverage = "Media Giornaliera"
    case monthlyComparison = "Confronto Mensile"
    case accountBalances = "Saldi Conti"
    case recentTransactions = "Transazioni Recenti"
    case upcomingBills = "Prossime Scadenze"
    case quickStats = "Statistiche Rapide"
    case dailyTrend = "Andamento Giornaliero"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .totalBalance: return "dollarsign.circle.fill"
        case .todaySummary: return "calendar.circle.fill"
        case .budgetProgress: return "chart.bar.fill"
        case .spendingByCategory: return "chart.pie.fill"
        case .incomeVsExpenses: return "arrow.up.arrow.down.circle.fill"
        case .netWorthTrend: return "chart.line.uptrend.xyaxis"
        case .topCategories: return "list.number"
        case .savingsRate: return "percent"
        case .dailyAverage: return "calendar.badge.clock"
        case .monthlyComparison: return "arrow.left.arrow.right.circle.fill"
        case .accountBalances: return "creditcard.fill"
        case .recentTransactions: return "clock.arrow.circlepath"
        case .upcomingBills: return "bell.fill"
        case .quickStats: return "square.grid.2x2.fill"
        case .dailyTrend: return "chart.xyaxis.line"
        }
    }

    var description: String {
        switch self {
        case .totalBalance: return "Mostra il saldo totale di tutti i conti"
        case .todaySummary: return "Riepilogo entrate e uscite di oggi"
        case .budgetProgress: return "Progresso dei budget impostati"
        case .spendingByCategory: return "Grafico a torta delle spese per categoria"
        case .incomeVsExpenses: return "Confronto entrate e uscite mensili"
        case .netWorthTrend: return "Andamento del patrimonio netto"
        case .topCategories: return "Top 5 categorie più utilizzate"
        case .savingsRate: return "Percentuale di risparmio mensile"
        case .dailyAverage: return "Spesa media giornaliera"
        case .monthlyComparison: return "Confronto mese corrente vs precedente"
        case .accountBalances: return "Saldi dei conti principali"
        case .recentTransactions: return "Ultime 5 transazioni"
        case .upcomingBills: return "Prossime transazioni programmate"
        case .quickStats: return "Statistiche rapide"
        case .dailyTrend: return "Grafico spese e entrate giornaliere"
        }
    }
}

struct WidgetModel: Identifiable, Codable, Equatable {
    let id: UUID
    var type: WidgetType
    var order: Int

    init(id: UUID = UUID(), type: WidgetType, order: Int = 0) {
        self.id = id
        self.type = type
        self.order = order
    }
}
