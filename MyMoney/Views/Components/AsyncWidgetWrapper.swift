//
//  AsyncWidgetWrapper.swift
//  MoneyTracker
//
//  Created on 2026-02-02.
//

import SwiftUI

/// Wrapper that loads widget content asynchronously to prevent UI blocking
struct AsyncWidgetWrapper<Content: View>: View {
    let content: () -> Content
    let delayMilliseconds: UInt64

    @State private var isLoaded = false

    init(
        delayMilliseconds: UInt64 = 0,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.content = content
        self.delayMilliseconds = delayMilliseconds
    }

    var body: some View {
        Group {
            if isLoaded {
                content()
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                WidgetSkeletonView()
                    .transition(.opacity)
            }
        }
        .task {
            // Add small delay to stagger widget loading
            if delayMilliseconds > 0 {
                try? await Task.sleep(nanoseconds: delayMilliseconds * 1_000_000)
            }

            // Load widget content in background
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    isLoaded = true
                }
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            AsyncWidgetWrapper(delayMilliseconds: 0) {
                VStack {
                    Text("Widget 1 Loaded")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(16)
            }

            AsyncWidgetWrapper(delayMilliseconds: 100) {
                VStack {
                    Text("Widget 2 Loaded")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.green.opacity(0.2))
                .cornerRadius(16)
            }

            AsyncWidgetWrapper(delayMilliseconds: 200) {
                VStack {
                    Text("Widget 3 Loaded")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .background(Color.orange.opacity(0.2))
                .cornerRadius(16)
            }
        }
        .padding()
    }
}
