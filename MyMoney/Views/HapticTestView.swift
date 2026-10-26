//
//  HapticTestView.swift
//  MoneyTracker
//
//  Created on 2026-01-26.
//  DEBUG VIEW - Remove in production
//

import SwiftUI

struct HapticTestView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Impact Feedback") {
                    Button("Light Impact") {
                        HapticManager.shared.light()
                    }

                    Button("Medium Impact") {
                        HapticManager.shared.medium()
                    }

                    Button("Heavy Impact") {
                        HapticManager.shared.heavy()
                    }

                    Button("Soft Impact") {
                        HapticManager.shared.soft()
                    }

                    Button("Rigid Impact") {
                        HapticManager.shared.rigid()
                    }
                }.listRowBackground(Color.orbCard)

                Section("Notification Feedback") {
                    Button("Success") {
                        HapticManager.shared.success()
                    }

                    Button("Warning") {
                        HapticManager.shared.warning()
                    }

                    Button("Error") {
                        HapticManager.shared.error()
                    }
                }.listRowBackground(Color.orbCard)

                Section("Selection Feedback") {
                    Button("Selection Changed") {
                        HapticManager.shared.selectionFeedback()
                    }
                }.listRowBackground(Color.orbCard)

                Section("Context-Specific") {
                    Button("Transaction Saved") {
                        HapticManager.shared.transactionSaved()
        NotificationCenter.default.post(name: .orbSaveFeedback, object: nil)
                    }

                    Button("Transaction Deleted") {
                        HapticManager.shared.transactionDeleted()
                    }

                    Button("Period Changed") {
                        HapticManager.shared.periodChanged()
                    }

                    Button("Chart Type Changed") {
                        HapticManager.shared.chartTypeChanged()
                    }
                }.listRowBackground(Color.orbCard)
            }.orbScreen()
            .navigationTitle("Haptic Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HapticTestView()
}
