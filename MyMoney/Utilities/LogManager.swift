//
//  LogManager.swift
//  MoneyTracker
//
//  Created on 2026-01-14.
//

import Foundation

enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case success = "✅ SUCCESS"
}

@MainActor
class LogManager {
    static let shared = LogManager()

    private let logFileName = "app_logs.txt"
    private let maxLogSize: Int = 5 * 1024 * 1024 // 5MB

    private var logFileURL: URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentDirectory.appendingPathComponent(logFileName)
    }

    private init() {
        // Crea il file se non esiste
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
            log("Log system initialized", level: .info, category: "System")
        }
    }

    // MARK: - Logging Functions

    func log(_ message: String, level: LogLevel = .info, category: String = "General") {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue)] [\(category)] \(message)\n"

        // Stampa anche in console per debug
        print(logEntry.trimmingCharacters(in: .whitespacesAndNewlines))

        // Scrivi su file
        writeToFile(logEntry)

        // Check se il file è troppo grande
        checkAndRotateLog()
    }

    func debug(_ message: String, category: String = "General") {
        log(message, level: .debug, category: category)
    }

    func info(_ message: String, category: String = "General") {
        log(message, level: .info, category: category)
    }

    func warning(_ message: String, category: String = "General") {
        log(message, level: .warning, category: category)
    }

    func error(_ message: String, category: String = "General") {
        log(message, level: .error, category: category)
    }

    func success(_ message: String, category: String = "General") {
        log(message, level: .success, category: category)
    }

    // MARK: - File Operations

    private func writeToFile(_ logEntry: String) {
        guard let data = logEntry.data(using: .utf8) else { return }

        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try? fileHandle.close()
        }
    }

    private func checkAndRotateLog() {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
              let fileSize = attributes[.size] as? Int else {
            return
        }

        if fileSize > maxLogSize {
            // Leggi le ultime 50% di righe e ricrea il file
            if let content = try? String(contentsOf: logFileURL, encoding: .utf8) {
                let lines = content.components(separatedBy: "\n")
                let halfIndex = lines.count / 2
                let recentLines = Array(lines.suffix(from: halfIndex))

                let newContent = recentLines.joined(separator: "\n")
                try? newContent.write(to: logFileURL, atomically: true, encoding: .utf8)

                log("Log file rotated (was too large)", level: .info, category: "System")
            }
        }
    }

    // MARK: - Reading Logs

    func getLogs() -> String {
        guard let content = try? String(contentsOf: logFileURL, encoding: .utf8) else {
            return "No logs available"
        }
        return content
    }

    func getRecentLogs(lines: Int = 100) -> String {
        let allLogs = getLogs()
        let logLines = allLogs.components(separatedBy: "\n")
        let recentLines = Array(logLines.suffix(lines))
        return recentLines.joined(separator: "\n")
    }

    // MARK: - Clear Logs

    func clearLogs() {
        try? "".write(to: logFileURL, atomically: true, encoding: .utf8)
        log("Logs cleared by user", level: .info, category: "System")
    }

    // MARK: - Export

    func getLogFileURL() -> URL {
        return logFileURL
    }

    func exportLogs() -> Data? {
        return try? Data(contentsOf: logFileURL)
    }
}
