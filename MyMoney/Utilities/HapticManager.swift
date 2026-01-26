//
//  HapticManager.swift
//  MoneyTracker
//
//  Created on 2026-01-26.
//

import UIKit

@MainActor
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    // MARK: - Impact Feedback

    /// Feedback leggero per azioni minori (tap su pulsanti, selezioni)
    func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Feedback medio per azioni normali
    func medium() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Feedback pesante per azioni importanti
    func heavy() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Feedback morbido e delicato
    func soft() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred()
    }

    /// Feedback rigido e deciso
    func rigid() {
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred()
    }

    // MARK: - Notification Feedback

    /// Feedback di successo (✓)
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    /// Feedback di warning (⚠️)
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.warning)
    }

    /// Feedback di errore (✗)
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }

    // MARK: - Selection Feedback

    /// Feedback per cambio di selezione (picker, segmented control, tab bar)
    func selectionFeedback() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    // MARK: - Context-Specific Feedback

    /// Feedback quando si salva una transazione
    func transactionSaved() {
        success()
    }

    /// Feedback quando si elimina una transazione
    func transactionDeleted() {
        warning()
    }

    /// Feedback quando si conferma una transazione ricorrente
    func recurringTransactionConfirmed() {
        success()
    }

    /// Feedback quando si esegue una transazione pending
    func transactionExecuted() {
        success()
    }

    /// Feedback quando si cambia periodo nel grafico
    func periodChanged() {
        selectionFeedback()
    }

    /// Feedback quando si cambia tipo di grafico
    func chartTypeChanged() {
        soft()
    }

    /// Feedback quando si applica un filtro
    func filterApplied() {
        light()
    }

    /// Feedback quando si crea/modifica un account
    func accountSaved() {
        success()
    }

    /// Feedback quando si elimina un account
    func accountDeleted() {
        warning()
    }

    /// Feedback quando si crea/modifica una categoria
    func categorySaved() {
        success()
    }

    /// Feedback quando si elimina una categoria
    func categoryDeleted() {
        warning()
    }

    /// Feedback quando si crea/modifica un budget
    func budgetSaved() {
        success()
    }

    /// Feedback quando si elimina un budget
    func budgetDeleted() {
        warning()
    }

    /// Feedback quando si seleziona un elemento
    func itemSelected() {
        soft()
    }

    /// Feedback quando si conferma un'azione importante
    func actionConfirmed() {
        medium()
    }

    /// Feedback quando si annulla un'azione
    func actionCancelled() {
        light()
    }

    /// Feedback per swipe actions
    func swipeAction() {
        light()
    }

    /// Feedback quando si raggiunge un limite (es. budget superato)
    func limitReached() {
        rigid()
    }
}
