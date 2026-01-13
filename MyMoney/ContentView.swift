//
//  ContentView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var biometricManager = BiometricAuthManager.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                BalanceView()
                    .tabItem {
                        Label("Bilancio", systemImage: "chart.bar.fill")
                    }
                    .tag(1)

                TodayView()
                    .tabItem {
                        Label("Oggi", systemImage: "plus.circle.fill")
                    }
                    .tag(2)

                ResocontoView()
                    .tabItem {
                        Label("Resoconto", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(3)

                SettingsView()
                    .tabItem {
                        Label("More", systemImage: "ellipsis")
                    }
                    .tag(4)
            }
            .accentColor(.blue)
            .blur(radius: shouldShowAuthScreen ? 10 : 0)

            // Biometric Authentication Overlay
            if shouldShowAuthScreen {
                BiometricAuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowAuthScreen)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(newPhase)
        }
    }

    private var shouldShowAuthScreen: Bool {
        biometricManager.isBiometricEnabled && !biometricManager.isAuthenticated
    }

    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .background, .inactive:
            // When app goes to background, require re-authentication
            if biometricManager.isBiometricEnabled {
                biometricManager.resetAuthenticationState()
            }
        case .active:
            // App became active - authentication screen will show if needed
            break
        @unknown default:
            break
        }
    }
}

#Preview {
    ContentView()
}
