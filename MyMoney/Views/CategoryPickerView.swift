//
//  CategoryPickerView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct CategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appSettings) var appSettings
    @Query(sort: \CategoryGroup.sortOrder) private var categoryGroups: [CategoryGroup]

    @Binding var selectedCategory: Category?
    let transactionType: TransactionType

    @State private var showingNewCategorySheet = false
    @State private var showingNewGroupSheet = false
    @State private var searchText = ""
    @State private var selectedCategoryForDetail: Category?
    @State private var showingGroupedView = false

    var filteredGroups: [CategoryGroup] {
        // Prima filtra per applicabilità al tipo di transazione
        let applicableGroups = categoryGroups.filter { group in
            group.applicability.isApplicable(to: transactionType)
        }

        // Poi filtra per ricerca testuale
        if searchText.isEmpty {
            return applicableGroups
        } else {
            return applicableGroups.compactMap { group in
                let filteredCategories = group.sortedCategories.filter {
                    $0.name.localizedCaseInsensitiveContains(searchText)
                }
                if filteredCategories.isEmpty {
                    return nil
                }
                return group
            }
        }
    }

    var body: some View {
        Group {
            if appSettings.groupedCategoryView {
                GroupedCategoryPickerView(selectedCategory: $selectedCategory) { category in
                    selectedCategory = category
                    dismiss()
                }
            } else {
                listView
            }
        }
    }
    
    private var listView: some View {
        NavigationStack {
            List {
                ForEach(filteredGroups) { group in
                    Section {
                        ForEach(group.sortedCategories.filter { category in
                            searchText.isEmpty || category.name.localizedCaseInsensitiveContains(searchText)
                        }) { category in
                            HStack(spacing: 12) {
                                Button {
                                    selectedCategory = category
                                    dismiss()
                                } label: {
                                    HStack(spacing: 12) {
                                        // Category icon (custom image or SF Symbol)
                                        if let imageData = category.imageData,
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 40, height: 40)
                                                .clipShape(Circle())
                                        } else {
                                            ZStack {
                                                Circle()
                                                    .fill(category.color.opacity(0.2))
                                                    .frame(width: 40, height: 40)

                                                Image(systemName: category.icon)
                                                    .foregroundStyle(category.color)
                                            }
                                        }

                                        Text(category.name)
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        if selectedCategory?.id == category.id {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())

                                Button {
                                    selectedCategoryForDetail = category
                                } label: {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(.secondary)
                                        .font(.title3)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    } header: {
                        HStack {
                            if let imageData = group.imageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 20, height: 20)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: group.icon)
                                    .foregroundStyle(group.color)
                            }
                            Text(group.name)
                        }
                    }
                }

                Section {
                    Button {
                        showingNewCategorySheet = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Nuova Categoria")
                        }
                    }

                    Button {
                        showingNewGroupSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .foregroundStyle(.green)
                            Text("Nuovo Gruppo")
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Cerca categoria")
            .navigationTitle("Seleziona Categoria")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingNewCategorySheet) {
                AddCategoryView(preselectedGroup: nil)
            }
            .sheet(isPresented: $showingNewGroupSheet) {
                AddCategoryGroupView()
            }
            .sheet(item: $selectedCategoryForDetail) { category in
                NavigationStack {
                    CategoryDetailView(category: category)
                }
            }
        }
    }
}

#Preview {
    CategoryPickerView(selectedCategory: .constant(nil), transactionType: .expense)
        .modelContainer(for: [Category.self, CategoryGroup.self])
}
