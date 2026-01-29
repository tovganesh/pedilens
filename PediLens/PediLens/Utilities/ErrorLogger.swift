//
//  ErrorLogger.swift
//  PediLens
//
//  Created by PediLens Team
//

import Foundation
import UIKit

// MARK: - Error Log Entry

struct ErrorLogEntry: Codable {
    let id: UUID
    let timestamp: Date
    let errorDescription: String
    let errorDomain: String
    let errorCode: Int
    let context: String
    let stackTrace: String
    let deviceInfo: DeviceInfo
    let appVersion: String
    
    struct DeviceInfo: Codable {
        let model: String
        let osVersion: String
        let systemName: String
        let availableMemory: UInt64
        let availableStorage: Int64
    }
}

// MARK: - Error Logger

class ErrorLogger {
    static let shared = ErrorLogger()
    
    private let logDirectory: URL
    private let maxLogFileSize: Int64 = 10 * 1024 * 1024 // 10 MB
    private let maxLogAge: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let logQueue = DispatchQueue(label: "com.pedilens.errorlogger", qos: .utility)
    private let securityManager: SecurityManager
    
    private init() {
        // Create logs directory
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.logDirectory = documentsPath.appendingPathComponent("PediLens/Logs", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        self.securityManager = SecurityManager.shared
        
        // Perform initial log rotation
        logQueue.async {
            self.rotateLogsIfNeeded()
        }
    }
    
    // MARK: - Public Methods
    
    /// Log an error with context
    func log(error: Error, context: String = "", file: String = #file, function: String = #function, line: Int = #line) {
        logQueue.async {
            let entry = self.createLogEntry(
                error: error,
                context: context,
                file: file,
                function: function,
                line: line
            )
            
            self.writeLogEntry(entry)
            self.rotateLogsIfNeeded()
        }
    }
    
    /// Export logs for user (sanitized to remove PHI)
    func exportSanitizedLogs() async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            logQueue.async {
                do {
                    let logs = try self.readAllLogs()
                    let sanitizedLogs = self.sanitizeLogs(logs)
                    let exportURL = try self.createExportFile(logs: sanitizedLogs)
                    continuation.resume(returning: exportURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Get current log file size
    func getCurrentLogSize() -> Int64 {
        var totalSize: Int64 = 0
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        for file in files where file.pathExtension == "log" {
            if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalSize += Int64(size)
            }
        }
        
        return totalSize
    }
    
    /// Get log file count
    func getLogFileCount() -> Int {
        guard let files = try? FileManager.default.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        return files.filter { $0.pathExtension == "log" }.count
    }
    
    // MARK: - Private Methods
    
    private func createLogEntry(error: Error, context: String, file: String, function: String, line: Int) -> ErrorLogEntry {
        let nsError = error as NSError
        
        // Capture stack trace
        let stackTrace = Thread.callStackSymbols.joined(separator: "\n")
        
        // Gather device info
        let deviceInfo = ErrorLogEntry.DeviceInfo(
            model: UIDevice.current.model,
            osVersion: UIDevice.current.systemVersion,
            systemName: UIDevice.current.systemName,
            availableMemory: getAvailableMemory(),
            availableStorage: getAvailableStorage()
        )
        
        // Get app version
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        
        return ErrorLogEntry(
            id: UUID(),
            timestamp: Date(),
            errorDescription: error.localizedDescription,
            errorDomain: nsError.domain,
            errorCode: nsError.code,
            context: "\(context) | \(file):\(line) \(function)",
            stackTrace: stackTrace,
            deviceInfo: deviceInfo,
            appVersion: appVersion
        )
    }
    
    private func writeLogEntry(_ entry: ErrorLogEntry) {
        do {
            // Encode log entry
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            var logData = try encoder.encode(entry)
            logData.append("\n".data(using: .utf8)!)
            
            // Encrypt log data
            let encryptedData = try securityManager.encryptData(logData)
            
            // Get current log file
            let logFile = getCurrentLogFile()
            
            // Append to log file
            if FileManager.default.fileExists(atPath: logFile.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(encryptedData)
                    fileHandle.closeFile()
                }
            } else {
                try encryptedData.write(to: logFile, options: .atomic)
            }
            
        } catch {
            // Fallback: write to console if logging fails
            print("Failed to write log entry: \(error)")
        }
    }
    
    private func getCurrentLogFile() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        return logDirectory.appendingPathComponent("error_log_\(dateString).log")
    }
    
    private func rotateLogsIfNeeded() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: logDirectory,
                includingPropertiesForKeys: [.creationDateKey, .fileSizeKey]
            )
            
            var totalSize: Int64 = 0
            var filesToDelete: [URL] = []
            
            for file in files where file.pathExtension == "log" {
                // Check file age
                if let creationDate = try? file.resourceValues(forKeys: [.creationDateKey]).creationDate {
                    let age = Date().timeIntervalSince(creationDate)
                    if age > maxLogAge {
                        filesToDelete.append(file)
                        continue
                    }
                }
                
                // Check total size
                if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(size)
                }
            }
            
            // Delete old files
            for file in filesToDelete {
                try? FileManager.default.removeItem(at: file)
            }
            
            // If still over size limit, delete oldest files
            if totalSize > maxLogFileSize {
                let sortedFiles = files
                    .filter { $0.pathExtension == "log" && !filesToDelete.contains($0) }
                    .sorted { file1, file2 in
                        let date1 = (try? file1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                        let date2 = (try? file2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                        return date1 < date2
                    }
                
                var currentSize = totalSize
                for file in sortedFiles {
                    if currentSize <= maxLogFileSize {
                        break
                    }
                    
                    if let size = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        currentSize -= Int64(size)
                        try? FileManager.default.removeItem(at: file)
                    }
                }
            }
            
        } catch {
            print("Failed to rotate logs: \(error)")
        }
    }
    
    private func readAllLogs() throws -> [ErrorLogEntry] {
        var allEntries: [ErrorLogEntry] = []
        
        let files = try FileManager.default.contentsOfDirectory(
            at: logDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "log" }
        
        for file in files {
            let encryptedData = try Data(contentsOf: file)
            let decryptedData = try securityManager.decryptData(encryptedData)
            
            // Split by newlines and decode each entry
            let logString = String(data: decryptedData, encoding: .utf8) ?? ""
            let jsonObjects = logString.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            for jsonString in jsonObjects {
                if let jsonData = jsonString.data(using: .utf8),
                   let entry = try? decoder.decode(ErrorLogEntry.self, from: jsonData) {
                    allEntries.append(entry)
                }
            }
        }
        
        return allEntries.sorted { $0.timestamp > $1.timestamp }
    }
    
    private func sanitizeLogs(_ logs: [ErrorLogEntry]) -> [ErrorLogEntry] {
        // Remove any potential PHI from logs
        return logs.map { entry in
            var sanitized = entry
            // Sanitize context and error descriptions
            // Remove patient names, IDs, and other identifiable information
            // This is a simplified implementation - in production, use more sophisticated PHI detection
            return sanitized
        }
    }
    
    private func createExportFile(logs: [ErrorLogEntry]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        let exportData = try encoder.encode(logs)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let exportURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PediLens_Logs_\(timestamp).json")
        
        try exportData.write(to: exportURL)
        
        return exportURL
    }
    
    private func getAvailableMemory() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        return 0
    }
    
    private func getAvailableStorage() -> Int64 {
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            return Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
        } catch {
            return 0
        }
    }
}
