//
//  AccentColorPickerView.swift
//  MoneyTracker
//
//  Created on 2026-01-08.
//

import SwiftUI

struct AccentColorPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings

    let colorPresets: [(name: String, hex: String)] = [
        ("Blu", "#007AFF"),        // iOS Default Blue
        ("Indaco", "#5856D6"),     // iOS Indigo
        ("Viola", "#AF52DE"),      // iOS Purple
        ("Rosa", "#FF2D55"),       // iOS Pink
        ("Rosso", "#FF3B30"),      // iOS Red
        ("Arancione", "#FF9500"),  // iOS Orange
        ("Giallo", "#FFCC00"),     // iOS Yellow
        ("Verde", "#34C759"),      // iOS Green
        ("Teal", "#5AC8FA"),       // iOS Teal
        ("Cyan", "#55BEF0"),       // Custom Cyan
        ("Marrone", "#A2845E"),    // iOS Brown
        ("Grigio", "#8E8E93"),     // iOS Gray
    ]

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview Card
                    previewCard

                    // Color Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(colorPresets, id: \.hex) { preset in
                            colorButton(name: preset.name, hex: preset.hex)
                        }
                    }
                    .padding()
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Colore Principale")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Chiudi") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Preview Card

    private var previewCard: some View {
        VStack(spacing: 16) {
            Text("Anteprima")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)

            VStack(spacing: 12) {
                // Header preview
                HStack {
                    Image(systemName: "calendar")
                        .foregroundStyle(appSettings.accentColor)
                    Text("Oggi")
                        .font(.title3.bold())
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(appSettings.accentColor)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(appSettings.accentColor.opacity(0.1))
                )

                // Card preview
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Esempio")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("€100.00")
                            .font(.title3.bold())
                            .foregroundStyle(appSettings.accentColor)
                    }
                    Spacer()
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 12))

                // Button preview
                Button {} label: {
                    Text("Pulsante di Esempio")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(appSettings.accentColor)
                        )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Color Button

    private func colorButton(name: String, hex: String) -> some View {
        let color = Color(hex: hex) ?? .blue
        let isSelected = appSettings.accentColorHex == hex

        return Button {
            withAnimation(.spring(response: 0.3)) {
                appSettings.accentColorHex = hex
            }
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 60, height: 60)

                    if isSelected {
                        Circle()
                            .strokeBorder(color, lineWidth: 3)
                            .frame(width: 70, height: 70)

                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .background(
                                Circle()
                                    .fill(color)
                                    .frame(width: 28, height: 28)
                            )
                    }
                }

                Text(name)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AccentColorPickerView()
        .environment(\.appSettings, AppSettings.shared)
}
