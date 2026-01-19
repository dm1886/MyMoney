//
//  EditCategoryView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct EditCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var category: Category

    @Query(sort: \CategoryGroup.sortOrder) private var categoryGroups: [CategoryGroup]
    @Query private var accounts: [Account]

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var selectedGroup: CategoryGroup?
    @State private var selectedDefaultAccount: Account?
    @State private var showingIconPicker = false
    @State private var showingDeleteAlert = false

    init(category: Category) {
        self.category = category
        _name = State(initialValue: category.name)
        _selectedIcon = State(initialValue: category.icon)
        _selectedColor = State(initialValue: category.color)
        _selectedGroup = State(initialValue: category.categoryGroup)
        _selectedDefaultAccount = State(initialValue: category.defaultAccount)
    }

    var body: some View {
        Form {
            Section("Informazioni") {
                TextField("Nome Categoria", text: $name)

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

            Section("Organizzazione") {
                Picker("Gruppo", selection: $selectedGroup) {
                    Text("Nessun Gruppo").tag(nil as CategoryGroup?)
                    ForEach(categoryGroups) { group in
                        HStack {
                            Image(systemName: group.icon)
                            Text(group.name)
                        }
                        .tag(group as CategoryGroup?)
                    }
                }

                Picker("Conto Predefinito", selection: $selectedDefaultAccount) {
                    Text("Nessuno").tag(nil as Account?)
                    ForEach(accounts) { account in
                        HStack {
                            Image(systemName: account.icon)
                            Text(account.name)
                        }
                        .tag(account as Account?)
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Elimina Categoria")
                        Spacer()
                    }
                }
            }
        }
        .navigationTitle("Modifica Categoria")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Salva") {
                    saveChanges()
                }
                .disabled(name.isEmpty)
            }
        }
        .sheet(isPresented: $showingIconPicker) {
            IconPickerView(selectedIcon: $selectedIcon)
        }
        .alert("Elimina Categoria", isPresented: $showingDeleteAlert) {
            Button("Annulla", role: .cancel) { }
            Button("Elimina", role: .destructive) {
                deleteCategory()
            }
        } message: {
            Text("Sei sicuro di voler eliminare questa categoria?")
        }
    }

    private func saveChanges() {
        category.name = name
        category.icon = selectedIcon
        category.colorHex = selectedColor.toHex() ?? "#007AFF"
        category.categoryGroup = selectedGroup
        category.defaultAccount = selectedDefaultAccount

        try? modelContext.save()
        dismiss()
    }

    private func deleteCategory() {
        modelContext.delete(category)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Category.self, CategoryGroup.self, configurations: config)

    let category = Category(name: "Test Category")
    container.mainContext.insert(category)

    return NavigationStack {
        EditCategoryView(category: category)
    }
    .modelContainer(container)
}
