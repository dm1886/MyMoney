//
//  EditCategoryView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?

    init(category: Category) {
        self.category = category
        _name = State(initialValue: category.name)
        _selectedIcon = State(initialValue: category.icon)
        _selectedColor = State(initialValue: category.color)
        _selectedGroup = State(initialValue: category.categoryGroup)
        _selectedDefaultAccount = State(initialValue: category.defaultAccount)
        _photoData = State(initialValue: category.imageData)
    }

    var body: some View {
        Form {
            // MARK: - Group Selection (First)
            Section {
                NavigationLink {
                    GroupSelectionView(selectedGroup: $selectedGroup)
                } label: {
                    HStack {
                        Text("Gruppo")
                        Spacer()
                        if let group = selectedGroup {
                            HStack(spacing: 8) {
                                if let imageData = group.imageData,
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: group.icon)
                                        .foregroundStyle(group.color)
                                }
                                Text(group.name)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Nessun Gruppo")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Text("Gruppo")
            } footer: {
                Text("Seleziona il gruppo a cui appartiene questa categoria")
            }

            // MARK: - Category Info
            Section("Informazioni") {
                TextField("Nome Categoria", text: $name)

                Button {
                    showingIconPicker = true
                } label: {
                    HStack {
                        Text("Icona")
                        Spacer()
                        if let photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        } else {
                            Image(systemName: selectedIcon)
                                .font(.title2)
                                .foregroundStyle(selectedColor)
                        }
                    }
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    HStack {
                        Text("Immagine Personalizzata")
                        Spacer()
                        if photoData != nil {
                            Button {
                                photoData = nil
                                selectedPhoto = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                ColorPicker("Colore", selection: $selectedColor)
            }

            // MARK: - Default Account
            Section {
                NavigationLink {
                    DefaultAccountSelectionView(selectedAccount: $selectedDefaultAccount)
                } label: {
                    HStack {
                        Text("Conto Predefinito")
                        Spacer()
                        if let account = selectedDefaultAccount {
                            HStack(spacing: 8) {
                                if let imageData = account.imageData,
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: account.icon)
                                        .foregroundStyle(Color(hex: account.colorHex) ?? .gray)
                                }
                                Text(account.name)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Nessuno")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } footer: {
                Text("Il conto selezionato automaticamente quando usi questa categoria")
            }

            // MARK: - Delete
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
        .onChange(of: selectedPhoto) { _, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
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
        category.imageData = photoData

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
