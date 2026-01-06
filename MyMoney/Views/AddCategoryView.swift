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
                CategoryIconPickerView(selectedIcon: $selectedIcon)
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

struct CategoryIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedIcon: String

    let categoryIcons = [
        "folder.fill", "fork.knife", "cup.and.saucer.fill", "cart.fill",
        "car.fill", "fuelpump.fill", "parkingsign.circle.fill", "bus.fill",
        "tram.fill", "airplane", "airplane.departure", "bed.double.fill",
        "house.fill", "bolt.fill", "wifi", "wrench.and.screwdriver.fill",
        "tshirt.fill", "laptopcomputer", "book.fill", "cross.case.fill",
        "figure.run", "sportscourt.fill", "dumbbell.fill", "bicycle",
        "heart.fill", "heart.text.square.fill", "gift.fill", "graduationcap.fill",
        "paintbrush.fill", "music.note", "film.fill", "gamecontroller.fill",
        "banknote.fill", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis",
        "briefcase.fill", "bag.fill", "takeoutbag.and.cup.and.straw.fill",
        "wineglass.fill", "birthday.cake.fill", "leaf.fill", "tree.fill",
        "pawprint.fill", "hare.fill", "tortoise.fill", "fish.fill"
    ]

    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(categoryIcons, id: \.self) { icon in
                        Button {
                            selectedIcon = icon
                            dismiss()
                        } label: {
                            VStack {
                                Image(systemName: icon)
                                    .font(.title)
                                    .foregroundStyle(selectedIcon == icon ? .blue : .primary)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        Circle()
                                            .fill(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                    )
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Scegli Icona")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fatto") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddCategoryView(preselectedGroup: nil)
        .modelContainer(for: [Category.self, CategoryGroup.self, Account.self])
}
