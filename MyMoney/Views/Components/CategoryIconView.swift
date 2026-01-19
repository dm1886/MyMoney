//
//  CategoryIconView.swift
//  MoneyTracker
//
//  Created on 2026-01-19.
//

import SwiftUI

/// A reusable view that displays either a custom image or SF Symbol for a category
struct CategoryIconView: View {
    let category: Category?
    var size: CGFloat = 24
    var cornerRadius: CGFloat = 6
    var fallbackIcon: String = "folder.fill"
    var fallbackColor: Color = .gray

    var body: some View {
        if let category = category {
            if let imageData = category.imageData,
               let uiImage = UIImage(data: imageData) {
                // Show custom image
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            } else {
                // Show SF Symbol icon
                Image(systemName: category.icon)
                    .font(.system(size: size * 0.7))
                    .foregroundStyle(category.color)
            }
        } else {
            // Fallback when no category
            Image(systemName: fallbackIcon)
                .font(.system(size: size * 0.7))
                .foregroundStyle(fallbackColor)
        }
    }
}

/// A variant with a circular background
struct CategoryIconWithBackground: View {
    let category: Category?
    var size: CGFloat = 44
    var iconSize: CGFloat = 24
    var fallbackIcon: String = "folder.fill"
    var fallbackColor: Color = .gray

    var body: some View {
        ZStack {
            if let category = category {
                if let imageData = category.imageData,
                   let uiImage = UIImage(data: imageData) {
                    // Custom image - no background circle needed
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    // SF Symbol with colored background
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: size, height: size)

                    Image(systemName: category.icon)
                        .font(.system(size: iconSize * 0.7))
                        .foregroundStyle(category.color)
                }
            } else {
                // Fallback
                Circle()
                    .fill(fallbackColor.opacity(0.2))
                    .frame(width: size, height: size)

                Image(systemName: fallbackIcon)
                    .font(.system(size: iconSize * 0.7))
                    .foregroundStyle(fallbackColor)
            }
        }
    }
}

/// For transaction rows that may not have a category
struct TransactionCategoryIcon: View {
    let transaction: Transaction
    var size: CGFloat = 44
    var iconSize: CGFloat = 24

    var body: some View {
        ZStack {
            if let category = transaction.category {
                if let imageData = category.imageData,
                   let uiImage = UIImage(data: imageData) {
                    // Custom image
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                } else {
                    // SF Symbol with colored background
                    Circle()
                        .fill(category.color.opacity(0.2))
                        .frame(width: size, height: size)

                    Image(systemName: category.icon)
                        .font(.system(size: iconSize * 0.7))
                        .foregroundStyle(category.color)
                }
            } else {
                // Fallback to transaction type icon
                let typeColor = Color(hex: transaction.transactionType.color) ?? .gray
                Circle()
                    .fill(typeColor.opacity(0.2))
                    .frame(width: size, height: size)

                Image(systemName: transaction.transactionType.icon)
                    .font(.system(size: iconSize * 0.7))
                    .foregroundStyle(typeColor)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        Text("CategoryIconView")
        CategoryIconView(category: nil, size: 32)

        Text("CategoryIconWithBackground")
        CategoryIconWithBackground(category: nil, size: 50, iconSize: 28)
    }
    .padding()
}
