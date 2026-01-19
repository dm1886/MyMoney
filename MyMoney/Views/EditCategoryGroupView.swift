//
//  EditCategoryGroupView.swift
//  MoneyTracker
//
//  Created on 2026-01-15.
//

import SwiftUI
import SwiftData
import PhotosUI

struct EditCategoryGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var group: CategoryGroup

    @State private var name: String
    @State private var selectedIcon: String
    @State private var selectedColor: Color
    @State private var selectedApplicability: TransactionTypeScope
    @State private var showingIconPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?

    init(group: CategoryGroup) {
        self.group = group
        _name = State(initialValue: group.name)
        _selectedIcon = State(initialValue: group.icon)
        _selectedColor = State(initialValue: group.color)
        _selectedApplicability = State(initialValue: group.applicability)
        _photoData = State(initialValue: group.imageData)
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
                                if let imageData = category.imageData,
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 24, height: 24)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: category.icon)
                                        .foregroundStyle(category.color)
                                }
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
                IconPickerView(selectedIcon: $selectedIcon)
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
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

        if group.imageData != photoData {
            changes.append("image updated")
            group.imageData = photoData
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
