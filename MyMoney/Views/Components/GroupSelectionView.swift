//
//  GroupSelectionView.swift
//  MoneyTracker
//
//  Created on 2026-01-19.
//

import SwiftUI
import SwiftData

struct GroupSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CategoryGroup.sortOrder) private var categoryGroups: [CategoryGroup]

    @Binding var selectedGroup: CategoryGroup?

    var body: some View {
        List {
            // Option for no group
            noneOptionRow

            // All groups
            Section {
                ForEach(categoryGroups) { group in
                    groupRow(group)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Seleziona Gruppo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var noneOptionRow: some View {
        Button {
            selectedGroup = nil
            dismiss()
        } label: {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 40, height: 40)

                    Image(systemName: "folder")
                        .foregroundStyle(.gray)
                }

                Text("Nessun Gruppo")
                    .foregroundStyle(.primary)

                Spacer()

                if selectedGroup == nil {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func groupRow(_ group: CategoryGroup) -> some View {
        Button {
            selectedGroup = group
            dismiss()
        } label: {
            HStack {
                groupIcon(group)

                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .foregroundStyle(.primary)

                    Text("\(group.categories?.count ?? 0) categorie")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if selectedGroup?.id == group.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                        .fontWeight(.semibold)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    @ViewBuilder
    private func groupIcon(_ group: CategoryGroup) -> some View {
        if let imageData = group.imageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
        } else {
            ZStack {
                Circle()
                    .fill(group.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: group.icon)
                    .foregroundStyle(group.color)
            }
        }
    }
}
