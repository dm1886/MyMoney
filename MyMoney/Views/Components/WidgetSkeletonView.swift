//
//  WidgetSkeletonView.swift
//  MoneyTracker
//
//  Created on 2026-02-02.
//

import SwiftUI

/// Skeleton placeholder shown while widget data is loading
struct WidgetSkeletonView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header skeleton
            HStack {
                Circle()
                    .fill(Color.orbMuted.opacity(0.2))
                    .frame(width: 28, height: 28)

                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.orbMuted.opacity(0.2))
                    .frame(width: 120, height: 20)

                Spacer()
            }

            // Content skeleton
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orbMuted.opacity(0.15))
                    .frame(height: 60)

                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orbMuted.opacity(0.1))
                        .frame(height: 40)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.orbMuted.opacity(0.1))
                        .frame(height: 40)
                }

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.orbMuted.opacity(0.15))
                    .frame(height: 80)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orbBackground)
        )
        .modifier(OrbShimmer())
    }
}

#Preview {
    WidgetSkeletonView()
        .padding()
}
