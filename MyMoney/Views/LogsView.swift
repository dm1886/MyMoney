//
//  LogsView.swift
//  MoneyTracker
//
//  Created on 2026-01-14.
//

import SwiftUI

struct LogsView: View {
    @Environment(\.appSettings) var appSettings
    @State private var logs: String = ""
    @State private var filterLevel: FilterLevel = .all
    @State private var showingShareSheet = false
    @State private var showingClearAlert = false
    @State private var autoRefresh = true
    @State private var refreshTask: Task<Void, Never>?

    enum FilterLevel: String, CaseIterable {
        case all = "Tutti"
        case error = "❌ Errori"
        case warning = "⚠️ Warning"
        case success = "✅ Success"
        case info = "ℹ️ Info"
        case debug = "🔍 Debug"
    }

    var filteredLogs: String {
        let allLogs = logs
        guard filterLevel != .all else { return allLogs }

        let lines = allLogs.components(separatedBy: "\n")
        let filtered = lines.filter { line in
            switch filterLevel {
            case .all:
                return true
            case .error:
                return line.contains("❌ ERROR")
            case .warning:
                return line.contains("⚠️ WARNING")
            case .success:
                return line.contains("✅ SUCCESS")
            case .info:
                return line.contains("ℹ️ INFO")
            case .debug:
                return line.contains("🔍 DEBUG")
            }
        }

        return filtered.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(FilterLevel.allCases, id: \.self) { level in
                            Button {
                                filterLevel = level
                            } label: {
                                Text(level.rawValue)
                                    .font(.orbSubheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(filterLevel == level ? Color.orbAccent.opacity(0.2) : Color.orbCard)
                                    )
                                    .foregroundStyle(filterLevel == level ? Color.orbAccent : Color.orbMuted)
                            }
                        }
                    }
                    .padding(.horizontal)
                }.orbScreen()
                .padding(.vertical, 12)

                Divider()

                // Logs Content
                if filteredLogs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.orbMuted)

                        Text("Nessun log")
                            .font(.orbHeadline)

                        Text("I log dell'app appariranno qui")
                            .font(.orbSubheadline)
                            .foregroundStyle(Color.orbMuted)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        ScrollViewReader { proxy in
                            VStack(alignment: .leading, spacing: 0) {
                                Text(filteredLogs)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Color.orbText)
                                    .textSelection(.enabled)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("bottom")
                            }
                            .onAppear {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                            .onChange(of: logs) { _, _ in
                                if autoRefresh {
                                    withAnimation {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                        }
                    }.orbScreen()
                }
            }
            .background(Color.orbBackground)
            .navigationTitle("Log Sistema")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        autoRefresh.toggle()
                    } label: {
                        Image(systemName: autoRefresh ? "arrow.clockwise.circle.fill" : "arrow.clockwise.circle")
                            .foregroundStyle(autoRefresh ? Color.orbAccent : Color.orbMuted)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            loadLogs()
                        } label: {
                            Label("Aggiorna", systemImage: "arrow.clockwise")
                        }

                        Button {
                            showingShareSheet = true
                        } label: {
                            Label("Condividi Log", systemImage: "square.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            showingClearAlert = true
                        } label: {
                            Label("Cancella Log", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                loadLogs()
                startAutoRefresh()
            }
            .onDisappear {
                stopAutoRefresh()
            }
            .onChange(of: autoRefresh) { _, newValue in
                if newValue {
                    startAutoRefresh()
                } else {
                    stopAutoRefresh()
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [LogManager.shared.getLogFileURL()])
            }
            .alert("Cancella Log", isPresented: $showingClearAlert) {
                Button("Annulla", role: .cancel) { }
                Button("Cancella", role: .destructive) {
                    LogManager.shared.clearLogs()
                    loadLogs()
                }
            } message: {
                Text("Sei sicuro di voler cancellare tutti i log?")
            }
        }
    }

    private func loadLogs() {
        logs = LogManager.shared.getLogs()
    }

    private func startAutoRefresh() {
        guard autoRefresh else { return }

        // Cancella il task precedente se esiste
        refreshTask?.cancel()

        // Crea un nuovo task per l'auto-refresh
        refreshTask = Task {
            while !Task.isCancelled && autoRefresh {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 secondi
                if !Task.isCancelled && autoRefresh {
                    await MainActor.run {
                        loadLogs()
                    }
                }
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    LogsView()
        .environment(\.appSettings, AppSettings.shared)
}
