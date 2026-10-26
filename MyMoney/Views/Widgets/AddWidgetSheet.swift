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
                Section("Intestazione saldo") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(BalanceHeaderStyle.allCases, id: \.self) { style in
                            Button {
                                appSettings.balanceHeaderStyle = style
                                HapticManager.shared.itemSelected()
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: style.icon)
                                    Text(style.rawValue).font(.orbCaption).multilineTextAlignment(.center)
                                }.frame(maxWidth: .infinity, minHeight: 76)
                                    .foregroundStyle(appSettings.balanceHeaderStyle == style ? Color.orbOnAccent : Color.orbText)
                                    .background(appSettings.balanceHeaderStyle == style ? Color.orbAccent : Color.orbCard2, in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(.plain)
                                .accessibilityAddTraits(appSettings.balanceHeaderStyle == style ? .isSelected : [])
                        }
                    }
                }.listRowBackground(Color.orbCard)
                Section("Widget in Home") {
                    ForEach(widgetManager.widgets) { widget in
                        HStack {
                            Button(role: .destructive) {
                                withAnimation { widgetManager.removeWidget(widget) }
                                HapticManager.shared.itemSelected()
                            } label: { Image(systemName: "minus.circle.fill").foregroundStyle(Color.orbNegative) }
                                .buttonStyle(.borderless).accessibilityLabel("Rimuovi " + widget.type.rawValue)
                            Label(widget.type.rawValue, systemImage: widget.type.icon).font(.orbBody)
                        }.transition(.move(edge: .top).combined(with: .opacity))
                    }.onMove { source, target in
                        widgetManager.moveWidget(from: source, to: target)
                        HapticManager.shared.itemSelected()
                    }
                }.listRowBackground(Color.orbCard)
                Section("Aggiungi widget") {
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
                                        .fill(Color.orbAccent.opacity(0.15))
                                        .frame(width: 50, height: 50)

                                    Image(systemName: widgetType.icon)
                                        .font(.orbTitle3)
                                        .foregroundStyle(Color.orbHighlight)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(widgetType.rawValue)
                                        .font(.orbHeadline)
                                        .foregroundStyle(Color.orbText)

                                    Text(widgetType.description)
                                        .font(.orbCaption)
                                        .foregroundStyle(Color.orbMuted)
                                        .lineLimit(2)
                                }

                                Spacer()

                                Image(systemName: "plus.circle.fill")
                                    .font(.orbTitle2)
                                    .foregroundStyle(Color.orbHighlight)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
                }.listRowBackground(Color.orbCard)
            }.orbScreen()
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Personalizza Home")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
            .presentationBackground(Color.orbBackground)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ripristina") {
                        widgetManager.widgets = [.totalBalance, .todaySummary, .dailyTrend, .budgetProgress, .quickStats].enumerated().map { WidgetModel(type: $0.element, order: $0.offset) }
                        widgetManager.saveWidgets()
                        appSettings.balanceHeaderStyle = .totalBalance
                        HapticManager.shared.itemSelected()
                    }.foregroundStyle(Color.orbMuted)
                }
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
    }
}

#Preview {
    AddWidgetSheet()
        .environment(\.appSettings, AppSettings.shared)
}
