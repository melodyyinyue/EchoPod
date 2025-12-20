import Foundation
import SwiftUI

/// 全局日志存储，用于在前端显示后端日志
@MainActor
class DebugLogStore: ObservableObject {
	static let shared = DebugLogStore()
	
	@Published var logs: [LogEntry] = []
	
	struct LogEntry: Identifiable {
		let id = UUID()
		let timestamp: Date
		let level: Level
		let message: String
		
		enum Level: String {
			case info = "ℹ️"
			case success = "✅"
			case warning = "⚠️"
			case error = "❌"
			case receive = "📩"
			case send = "📤"
			case event = "📨"
		}
	}
	
	private init() {}
	
	func log(_ message: String, level: LogEntry.Level = .info) {
		let entry = LogEntry(timestamp: Date(), level: level, message: message)
		logs.append(entry)
		// 保持最近 500 条日志
		if logs.count > 500 {
			logs.removeFirst(logs.count - 500)
		}
		// 同时打印到控制台
		print("[\(level.rawValue)] \(message)")
	}
	
	func clear() {
		logs.removeAll()
	}
	
	// 便捷方法
	func info(_ message: String) { log(message, level: .info) }
	func success(_ message: String) { log(message, level: .success) }
	func warning(_ message: String) { log(message, level: .warning) }
	func error(_ message: String) { log(message, level: .error) }
	func receive(_ message: String) { log(message, level: .receive) }
	func send(_ message: String) { log(message, level: .send) }
	func event(_ message: String) { log(message, level: .event) }
}

// 全局快捷函数
func debugLog(_ message: String, level: DebugLogStore.LogEntry.Level = .info) {
	Task { @MainActor in
		DebugLogStore.shared.log(message, level: level)
	}
}
