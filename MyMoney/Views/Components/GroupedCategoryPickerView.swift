//
//  GroupedCategoryPickerView.swift
//  MoneyTracker
//
//  Created on 2026-02-07.
//

import SwiftUI
import SwiftData

struct GroupedCategoryPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    @Environment(\.modelContext) private var modelContext
    @Query private var categoryGroups: [CategoryGroup]
    @Query private var budgets: [Budget]
    @Query private var transactions: [Transaction]
    
    @Binding var selectedCategory: Category?
    let onSelect: (Category) -> Void
    
    @State private var showingAddGroup = false
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    // Add Group Button
                    Button {
                        showingAddGroup = true
                    } label: {
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundStyle(.blue)
                            }
                            
                            VStack(spacing: 4) {
                                Text("Nuovo Gruppo")
                                    .font(.caption.bold())
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(height: 32, alignment: .top)
                                
                                Text("Aggiungi")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: 140)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Existing Groups
                    ForEach(sortedGroups) { group in
                        NavigationLink {
                            CategoryGridView(
                                group: group,
                                selectedCategory: $selectedCategory,
                                budgets: budgets,
                                transactions: transactions,
                                modelContext: modelContext,
                                onSelect: { category in
                                    onSelect(category)
                                    dismiss()
                                }
                            )
                        } label: {
                            GroupCardLabel(
                                group: group,
                                budgetStatus: getBudgetStatus(for: group)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Seleziona Gruppo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddGroup) {
                AddCategoryGroupView()
            }
        }
    }
    
    private var sortedGroups: [CategoryGroup] {
        categoryGroups.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    private func getBudgetStatus(for group: CategoryGroup) -> BudgetStatus? {
        // Cerca budget nelle categorie del gruppo
        guard let categories = group.categories, !categories.isEmpty else { return nil }
        
        var totalPercentage: Double = 0
        var budgetCount = 0
        var maxColor: Color = .green
        
        for category in categories {
            guard let budget = budgets.first(where: { $0.category?.id == category.id }) else {
                continue
            }
            
            let percentage = budget.percentageUsed(transactions: transactions, context: modelContext)
            totalPercentage += percentage
            budgetCount += 1
            
            // Determina il colore peggiore (rosso > arancione > giallo > verde)
            if percentage >= 100 {
                maxColor = .red
            } else if percentage >= 80 && maxColor != .red {
                maxColor = .orange
            } else if percentage >= 60 && maxColor != .red && maxColor != .orange {
                maxColor = .yellow
            }
        }
        
        if budgetCount > 0 {
            let avgPercentage = totalPercentage / Double(budgetCount)
            return BudgetStatus(percentage: avgPercentage, color: maxColor)
        }
        
        return nil
    }
    
    private func getBudgetColor(percentage: Double) -> Color {
        if percentage >= 100 {
            return .red
        } else if percentage >= 80 {
            return .orange
        } else if percentage >= 60 {
            return .yellow
        } else {
            return .green
        }
    }
}

struct BudgetStatus {
    let percentage: Double
    let color: Color
}

// MARK: - Group Card Label

struct GroupCardLabel: View {
    let group: CategoryGroup
    let budgetStatus: BudgetStatus?
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Budget progress ring
                if let status = budgetStatus {
                    // Background ring
                    Circle()
                        .stroke(status.color.opacity(0.2), lineWidth: 4)
                        .frame(width: 70, height: 70)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: min(status.percentage / 100, 1.0))
                        .stroke(status.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: status.percentage)
                }
                
                // Icon
                Circle()
                    .fill(Color(hex: group.colorHex)?.opacity(0.15) ?? .gray.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Image(systemName: group.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(Color(hex: group.colorHex) ?? .gray)
            }
            
            VStack(spacing: 4) {
                Text(group.name)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 32, alignment: .top)
                
                Text("\(group.categories?.count ?? 0) categorie")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 140)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Category Grid View

struct CategoryGridView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appSettings) var appSettings
    
    let group: CategoryGroup
    @Binding var selectedCategory: Category?
    let budgets: [Budget]
    let transactions: [Transaction]
    let modelContext: ModelContext
    let onSelect: (Category) -> Void
    
    @State private var showingAddCategory = false
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    // Add Category Button
                    Button {
                        showingAddCategory = true
                    } label: {
                        VStack(spacing: 8) {
                            // Icon container con altezza fissa
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 46, height: 46)
                                
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.blue)
                            }
                            .frame(height: 56)
                            
                            // Text container con altezza fissa
                            VStack(spacing: 2) {
                                Text("Nuova Categoria")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(height: 28, alignment: .top)
                                
                                Text(" ")
                                    .font(.caption2)
                                    .frame(height: 14)
                            }
                            .frame(height: 42)
                        }
                        .frame(maxWidth: .infinity, minHeight: 114)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.secondarySystemGroupedBackground))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Existing Categories
                    ForEach(sortedCategories) { category in
                        CategoryCard(
                            category: category,
                            budgetStatus: getBudgetStatus(for: category),
                            isSelected: selectedCategory?.id == category.id
                        ) {
                            onSelect(category)
                        }
                    }
                    
                    // Empty state if no categories
                    if sortedCategories.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tray")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Nessuna categoria in questo gruppo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                        .gridCellColumns(4)
                    }
                }
                .padding()
            }
            .navigationTitle(group.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddCategory) {
                AddCategoryView(preselectedGroup: group)
            }
        }
    }
    
    private var sortedCategories: [Category] {
        group.sortedCategories
    }
    
    private func getBudgetStatus(for category: Category) -> BudgetStatus? {
        guard let budget = budgets.first(where: { $0.category?.id == category.id }) else {
            return nil
        }
        
        // Calcola la percentuale effettiva usando il budget
        let percentage = budget.percentageUsed(transactions: transactions, context: modelContext)
        
        // Determina il colore in base alla percentuale
        let color: Color
        if percentage >= 100 {
            color = .red
        } else if percentage >= 80 {
            color = .orange
        } else if percentage >= 60 {
            color = .yellow
        } else {
            color = .green
        }
        
        return BudgetStatus(percentage: percentage, color: color)
    }
}

// MARK: - Category Card

struct CategoryCard: View {
    let category: Category
    let budgetStatus: BudgetStatus?
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Icon container con altezza fissa
                ZStack {
                    // Budget progress ring
                    if let status = budgetStatus {
                        // Background ring
                        Circle()
                            .stroke(status.color.opacity(0.2), lineWidth: 3)
                            .frame(width: 56, height: 56)
                        
                        // Progress ring
                        Circle()
                            .trim(from: 0, to: min(status.percentage / 100, 1.0))
                            .stroke(status.color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 56, height: 56)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.5), value: status.percentage)
                    }
                    
                    // Icon with custom image or SF Symbol
                    if let imageData = category.imageData,
                       let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color(hex: category.colorHex)?.opacity(0.15) ?? .gray.opacity(0.15))
                            .frame(width: 46, height: 46)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: category.colorHex) ?? .gray)
                    }
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .strokeBorder(Color.blue, lineWidth: 3)
                            .frame(width: 56, height: 56)
                    }
                }
                .frame(height: 56)
                
                // Text container con altezza fissa
                VStack(spacing: 2) {
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(height: 28, alignment: .top)
                    
                    // Mostra percentuale budget con altezza fissa
                    Group {
                        if let status = budgetStatus {
                            Text("\(Int(status.percentage))%")
                                .font(.caption2.bold())
                                .foregroundStyle(status.color)
                        } else {
                            Text(" ")
                                .font(.caption2)
                        }
                    }
                    .frame(height: 14)
                }
                .frame(height: 42)
            }
            .frame(maxWidth: .infinity, minHeight: 114)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @State var selectedCategory: Category?

    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CategoryGroup.self, Category.self, Budget.self, configurations: config)

    return GroupedCategoryPickerView(selectedCategory: $selectedCategory) { _ in }
        .environment(\.appSettings, AppSettings.shared)
        .modelContainer(container)
}
