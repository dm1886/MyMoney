//
//  AddCategoryGroupView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddCategoryGroupView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryGroup.sortOrder) private var existingGroups: [CategoryGroup]

    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColor = Color.blue
    @State private var selectedApplicability = TransactionTypeScope.all
    @State private var showingIconPicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?

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

    private func saveGroup() {
        let maxSortOrder = existingGroups.map { $0.sortOrder }.max() ?? 0

        let group = CategoryGroup(
            name: name,
            icon: selectedIcon,
            colorHex: selectedColor.toHex() ?? "#007AFF",
            sortOrder: maxSortOrder + 1,
            applicability: selectedApplicability
        )
        group.imageData = photoData

        modelContext.insert(group)
        try? modelContext.save()

        LogManager.shared.success("Created category group '\(name)' with applicability: \(selectedApplicability.rawValue)", category: "CategoryGroup")
        dismiss()
    }
}

#Preview {
    AddCategoryGroupView()
        .modelContainer(for: [CategoryGroup.self])
}
