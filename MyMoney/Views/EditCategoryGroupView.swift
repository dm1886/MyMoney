//
//  EditCategoryGroupView.swift
//  MoneyTracker
//
//  Created on 2026-01-15.
//

import SwiftUI
import SwiftData

struct EditCategoryGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var group: CategoryGroup

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var selectedApplicability: TransactionTypeScope
    @State private var showingIconPicker = false

    init(group: CategoryGroup) {
        self.group = group
        _name = State(initialValue: group.name)
        _selectedIcon = State(initialValue: group.icon)
        _selectedColor = State(initialValue: group.color)
        _selectedApplicability = State(initialValue: group.applicability)
    }

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

                Section {
                    Picker("Applicabilità", selection: $selectedApplicability) {
                        ForEach(TransactionTypeScope.allCases, id: \.self) { scope in
                            HStack {
                                Image(systemName: scope.icon)
                                Text(scope.rawValue)
                            }
                            .tag(scope)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Visibilità")
                } footer: {
                    Text("Scegli in quali tipi di transazione questo gruppo e le sue categorie saranno visibili")
                }

                // Mostra le categorie associate
                if let categories = group.categories, !categories.isEmpty {
                    Section {
                        ForEach(categories.sorted(by: { $0.name < $1.name })) { category in
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundStyle(category.color)
                                Text(category.name)
                            }
                        }
                    } header: {
                        Text("Categorie (\(categories.count))")
                    }
                }
            }
            .navigationTitle("Modifica Gruppo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                CategoryIconPickerView(selectedIcon: $selectedIcon)
            }
        }
    }

    private func saveChanges() {
        var changes: [String] = []

        if group.name != name {
            changes.append("name: '\(group.name)' → '\(name)'")
            group.name = name
        }

        if group.icon != selectedIcon {
            changes.append("icon: '\(group.icon)' → '\(selectedIcon)'")
            group.icon = selectedIcon
        }

        let newColorHex = selectedColor.toHex() ?? "#007AFF"
        if group.colorHex != newColorHex {
            changes.append("color: '\(group.colorHex)' → '\(newColorHex)'")
            group.colorHex = newColorHex
        }

        if group.applicability != selectedApplicability {
            changes.append("applicability: '\(group.applicability.rawValue)' → '\(selectedApplicability.rawValue)'")
            group.applicability = selectedApplicability
        }

        do {
            try modelContext.save()
            if !changes.isEmpty {
                LogManager.shared.success("Updated category group '\(group.name)'. Changes: \(changes.joined(separator: ", "))", category: "CategoryGroup")
            }
        } catch {
            LogManager.shared.error("Failed to save category group '\(group.name)': \(error.localizedDescription)", category: "CategoryGroup")
        }

        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CategoryGroup.self, configurations: config)

    let group = CategoryGroup(name: "Test Group", icon: "folder.fill", colorHex: "#007AFF", sortOrder: 0)
    container.mainContext.insert(group)

    return EditCategoryGroupView(group: group)
        .modelContainer(container)
}
