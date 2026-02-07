//
//  CategoryReportSkeletonView.swift
//  MoneyTracker
//
//  Created on 2026-02-05.
//

import SwiftUI

/// Skeleton placeholder shown while category report data is loading
struct CategoryReportSkeletonView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Period Selector Skeleton
                periodSelectorSkeleton
                    .padding(.horizontal)
                    .padding(.top, 16)
                
                // Account Filter Skeleton
                accountFilterSkeleton
                    .padding(.horizontal)
                
                // Total Card Skeleton
                totalCardSkeleton
                    .padding(.horizontal)
                
                // Chart Type Toggle Skeleton
                chartToggleSkeleton
                    .padding(.horizontal)
                
                // Chart Skeleton
                chartSkeleton
                    .padding(.horizontal)
                
                // Category List Skeleton
                categoryListSkeleton
                    .padding(.horizontal)
                    .padding(.bottom, 20)
            }
        }
        .background(Color(.systemGroupedBackground))
        .overlay(
            shimmerOverlay
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
    
    // MARK: - Period Selector Skeleton
    
    private var periodSelectorSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 20)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.15))
                            .frame(width: 100, height: 36)
                    }
                }
            }
            
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.1))
                .frame(width: 150, height: 14)
        }
    }
    
    // MARK: - Account Filter Skeleton
    
    private var accountFilterSkeleton: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 18)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 100, height: 14)
            }
            
            Spacer()
            
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Total Card Skeleton
    
    private var totalCardSkeleton: some View {
        HStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 32, height: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 90, height: 14)
                
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 120, height: 24)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Chart Toggle Skeleton
    
    private var chartToggleSkeleton: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 90, height: 34)
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 90, height: 34)
        }
    }
    
    // MARK: - Chart Skeleton
    
    private var chartSkeleton: some View {
        VStack(spacing: 16) {
            // Pie chart circle skeleton
            Circle()
                .fill(Color.gray.opacity(0.15))
                .frame(width: 200, height: 200)
                .overlay(
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 124, height: 124)
                )
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Category List Skeleton
    
    private var categoryListSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 150, height: 20)
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { _ in
                    categoryRowSkeleton
                }
            }
        }
    }
    
    private var categoryRowSkeleton: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 100, height: 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.15))
                    .frame(width: 50, height: 12)
            }
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 80, height: 16)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    // MARK: - Shimmer Overlay
    
    private var shimmerOverlay: some View {
        GeometryReader { geometry in
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.white.opacity(0.3),
                    Color.clear
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 0.5)
            .offset(x: isAnimating ? geometry.size.width : -geometry.size.width * 0.5)
        }
        .allowsHitTesting(false)
    }
}

#Preview {
    NavigationStack {
        CategoryReportSkeletonView()
            .navigationTitle("Spese per Categoria")
            .navigationBarTitleDisplayMode(.inline)
    }
}
