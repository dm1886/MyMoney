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
                }

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
                }

                Section("Selection Feedback") {
                    Button("Selection Changed") {
                        HapticManager.shared.selectionFeedback()
                    }
                }

                Section("Context-Specific") {
                    Button("Transaction Saved") {
                        HapticManager.shared.transactionSaved()
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
                }
            }
            .navigationTitle("Haptic Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    HapticTestView()
}
