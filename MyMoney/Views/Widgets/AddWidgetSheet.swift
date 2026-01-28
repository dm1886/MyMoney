//
//  AddWidgetSheet.swift
//  MoneyTracker
//
//  Created on 2026-01-27.
//

import SwiftUI

struct AddWidgetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @State private var widgetManager = WidgetManager.shared

    var availableWidgets: [WidgetType] {
        widgetManager.availableWidgets()
    }

    var body: some View {
        NavigationStack {
            List {
                if availableWidgets.isEmpty {
                    ContentUnavailableView(
                        "Tutti i Widget Aggiunti",
                        systemImage: "checkmark.circle.fill",
                        description: Text("Hai già aggiunto tutti i widget disponibili alla tua Home")
                    )
                } else {
                    ForEach(availableWidgets) { widgetType in
                        Button {
                            addWidget(widgetType)
                        } label: {
                            HStack(spacing: 16) {
                                ZStack {
                                    Circle()
                                        .fill(appSettings.accentColor.opacity(0.15))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: widgetType.icon)
                                        .font(.title3)
                                        .foregroundStyle(appSettings.accentColor)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(widgetType.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(.primary)

                                    Text(widgetType.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(appSettings.accentColor)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
            .navigationTitle("Aggiungi Widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fine") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func addWidget(_ type: WidgetType) {
        HapticManager.shared.itemSelected()
        let widget = WidgetModel(type: type)
        widgetManager.addWidget(widget)
        dismiss()
    }
}

#Preview {
    AddWidgetSheet()
        .environment(\.appSettings, AppSettings.shared)
}
