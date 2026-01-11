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
    @Query(sort: \CategoryGroup.sortOrder) private var categoryGroups: [CategoryGroup]

    @Binding var selectedCategory: Category?
    let transactionType: TransactionType

    @State private var showingNewCategorySheet = false
    @State private var searchText = ""
    @State private var selectedCategoryForDetail: Category?

    var filteredGroups: [CategoryGroup] {
        if searchText.isEmpty {
            return categoryGroups
        } else {
            return categoryGroups.compactMap { group in
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
                                        ZStack {
                                            Circle()
                                                .fill(category.color.opacity(0.2))
                                                .frame(width: 40, height: 40)

                                            Image(systemName: category.icon)
                                                .foregroundStyle(category.color)
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
                            Image(systemName: group.icon)
                                .foregroundStyle(group.color)
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
