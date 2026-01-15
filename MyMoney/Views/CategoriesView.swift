//
//  CategoriesView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI
import SwiftData

struct CategoriesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CategoryGroup.sortOrder) private var categoryGroups: [CategoryGroup]

    @State private var showingAddGroup = false
    @State private var showingAddCategory = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(categoryGroups) { group in
                    Section {
                        ForEach(group.sortedCategories) { category in
                            NavigationLink(destination: EditCategoryView(category: category)) {
                                CategoryRow(category: category)
                            }
                        }
                        .onDelete { indexSet in
                            deleteCategories(at: indexSet, in: group)
                        }

                        Button {
                            showingAddCategory = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("Aggiungi Categoria")
                                    .foregroundStyle(.blue)
                            }
                        }
                    } header: {
                        // Gruppo cliccabile per modificarlo
                        NavigationLink(destination: EditCategoryGroupView(group: group)) {
                            HStack {
                                Image(systemName: group.icon)
                                    .foregroundStyle(group.color)
                                Text(group.name)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        showingAddGroup = true
                    } label: {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                                .foregroundStyle(.green)
                            Text("Nuovo Gruppo")
                                .foregroundStyle(.green)
                        }
                    }
                }
            }
            .navigationTitle("Categorie")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAddGroup) {
                AddCategoryGroupView()
            }
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView(preselectedGroup: nil)
            }
        }
    }

    private func deleteCategories(at offsets: IndexSet, in group: CategoryGroup) {
        for index in offsets {
            let category = group.sortedCategories[index]
            modelContext.delete(category)
        }
        try? modelContext.save()
    }
}

struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: category.icon)
                    .foregroundStyle(category.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(category.name)
                    .font(.body)

                if let defaultAccount = category.defaultAccount {
                    Text("Conto: \(defaultAccount.name)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }
}

#Preview {
    CategoriesView()
        .modelContainer(for: [Category.self, CategoryGroup.self])
}
