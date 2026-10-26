//
//  ContentView.swift
//  MoneyTracker
//
//  Created on 2026-01-01.
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var keyboardVisible = false
    @State private var showingNewTransaction = false
    @State private var newTransactionType: TransactionType?
    @State private var biometricManager = BiometricAuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appSettings) private var appSettings

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                HomeViewNew()
                    .toolbar(.hidden, for: .tabBar)
                    .modifier(OrbTabActivity(active: selectedTab == 0 && !shouldShowAuthScreen))
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                    .tag(0)

                BalanceView()
                    .toolbar(.hidden, for: .tabBar)
                    .modifier(OrbTabActivity(active: selectedTab == 1 && !shouldShowAuthScreen))
                    .tabItem {
                        Label("Bilancio", systemImage: "chart.bar.fill")
                    }
                    .tag(1)

                TodayView()
                    .toolbar(.hidden, for: .tabBar)
                    .modifier(OrbTabActivity(active: selectedTab == 2 && !shouldShowAuthScreen))
                    .tabItem {
                        Label("Oggi", systemImage: "calendar")
                    }
                    .tag(2)

                ResocontoView()
                    .toolbar(.hidden, for: .tabBar)
                    .modifier(OrbTabActivity(active: selectedTab == 3 && !shouldShowAuthScreen))
                    .tabItem {
                        Label("Resoconto", systemImage: "chart.bar.doc.horizontal")
                    }
                    .tag(3)

                SettingsView()
                    .toolbar(.hidden, for: .tabBar)
                    .modifier(OrbTabActivity(active: selectedTab == 4 && !shouldShowAuthScreen))
                    .tabItem {
                        Label("More", systemImage: "ellipsis")
                    }
                    .tag(4)
            }
            .padding(.bottom, keyboardVisible ? 0 : 82)
            .overlay(alignment: .bottom) {
                if !keyboardVisible {
                    OrbCapsuleTabBar(selection: $selectedTab) {
                        if selectedTab == 2 {
                            NotificationCenter.default.post(name: .orbAddTransaction, object: nil)
                        } else { showingNewTransaction = true }
                    }
                }
            }
            .sheet(isPresented: $showingNewTransaction) {
                AddTransactionView(transactionType: .expense)
            }
            .sheet(item: $newTransactionType) { AddTransactionView(transactionType: $0) }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
            .onReceive(NotificationCenter.default.publisher(for: .orbShowDate)) { _ in selectedTab = 2 }
            .tint(Color.orbHighlight)
            .allowsHitTesting(!shouldShowAuthScreen)
            .blur(radius: shouldShowAuthScreen ? 10 : 0)

            // Biometric Authentication Overlay
            if shouldShowAuthScreen {
                BiometricAuthView()
                    .transition(.opacity)
            }
        }
        .modifier(InvestmentLifecycle())
        .modifier(OrbSaveFeedback())
        .modifier(OrbThemeScope())
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
            // When app goes to background, require re-authentication based on superSecure setting
            if biometricManager.isBiometricEnabled {
                // If superSecure is ON, lock immediately when going to background
                // If superSecure is OFF, don't lock (authentication will only be required on fresh app launch)
                if appSettings.superSecure {
                    biometricManager.resetAuthenticationState()
                }
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
