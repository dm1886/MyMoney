//
//  AddCategoryView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryGroup.sortOrder) private var categoryGroups: [CategoryGroup]
    @Query private var accounts: [Account]

    let preselectedGroup: CategoryGroup?

    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = Color.blue
    @State private var selectedGroup: CategoryGroup?
    @State private var selectedDefaultAccount: Account?
    @State private var showingIconPicker = false

    var body: some View {
        NavigationStack {
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
            }
            .navigationTitle("Nuova Categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showingIconPicker) {
                IconPickerView(selectedIcon: $selectedIcon)
            }
            .onAppear {
                selectedGroup = preselectedGroup ?? categoryGroups.first
            }
        }
    }

    private func saveCategory() {
        let category = Category(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColor.toHex() ?? "#007AFF",
            categoryGroup: selectedGroup,
            defaultAccount: selectedDefaultAccount
        )

        modelContext.insert(category)
        try? modelContext.save()

        dismiss()
    }
}

#Preview {
    AddCategoryView(preselectedGroup: nil)
        .modelContainer(for: [Category.self, CategoryGroup.self, Account.self])
}
