//
//  AddCategoryGroupView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct AddCategoryGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryGroup.sortOrder) private var existingGroups: [CategoryGroup]

    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = Color.blue
    @State private var showingIconPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Informazioni") {
                    TextField("Nome Gruppo", text: $name)

                    Button {
                        showingIconPicker = true
                    } label: {
                        HStack {
                            Text("Icona")
                            Spacer()
                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundStyle(selectedColor)
                        }
                    }

                    ColorPicker("Colore", selection: $selectedColor)
                }
            }
            .navigationTitle("Nuovo Gruppo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveGroup()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                CategoryIconPickerView(selectedIcon: $selectedIcon)
            }
        }
    }

    private func saveGroup() {
        let maxSortOrder = existingGroups.map { $0.sortOrder }.max() ?? 0

        let group = CategoryGroup(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColor.toHex() ?? "#007AFF",
            sortOrder: maxSortOrder + 1
        )

        modelContext.insert(group)
        try? modelContext.save()

        dismiss()
    }
}

#Preview {
    AddCategoryGroupView()
        .modelContainer(for: [CategoryGroup.self])
}
