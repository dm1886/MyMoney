//
//  AddCategoryView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import PhotosUI

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
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var hasInitializedGroup = false

    var body: some View {
        NavigationStack {
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
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
            .onAppear {
                // Inizializza il gruppo SOLO la prima volta, non ogni volta che la vista appare
                if !hasInitializedGroup {
                    selectedGroup = preselectedGroup ?? categoryGroups.first
                    hasInitializedGroup = true
                }
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
        category.imageData = photoData

        modelContext.insert(category)
        try? modelContext.save()

        // Haptic feedback for successful category creation
        HapticManager.shared.categorySaved()

        dismiss()
    }
}

#Preview {
    AddCategoryView(preselectedGroup: nil)
        .modelContainer(for: [Category.self, CategoryGroup.self, Account.self])
}
