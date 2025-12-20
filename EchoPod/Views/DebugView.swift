import SwiftUI

struct DebugView: View {
	@StateObject private var logStore = DebugLogStore.shared
	@State private var autoScroll = true
	
	var body: some View {
		VStack(spacing: 0) {
			// 工具栏
			HStack {
				Text("调试日志")
					.font(.headline)
				
				Spacer()
				
				Text("\(logStore.logs.count) 条")
					.font(.caption)
					.foregroundStyle(.secondary)
				
				Toggle("自动滚动", isOn: $autoScroll)
					.toggleStyle(.switch)
					.controlSize(.small)
				
				Button("清空") {
					logStore.clear()
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
			}
			.padding(.horizontal)
			.padding(.vertical, 8)
			.background(Color(nsColor: .windowBackgroundColor))
			
			Divider()
			
			// 日志列表
			ScrollViewReader { proxy in
				ScrollView {
					LazyVStack(alignment: .leading, spacing: 2) {
						ForEach(logStore.logs) { entry in
							LogEntryRow(entry: entry)
								.id(entry.id)
						}
					}
					.padding(8)
				}
				.onChange(of: logStore.logs.count) { _, _ in
					if autoScroll, let last = logStore.logs.last {
						withAnimation(.easeOut(duration: 0.1)) {
							proxy.scrollTo(last.id, anchor: .bottom)
						}
					}
				}
			}
			.background(Color(nsColor: .textBackgroundColor))
		}
		.navigationTitle("调试")
	}
}

struct LogEntryRow: View {
	let entry: DebugLogStore.LogEntry
	
	private var timeString: String {
		let formatter = DateFormatter()
		formatter.dateFormat = "HH:mm:ss.SSS"
		return formatter.string(from: entry.timestamp)
	}
	
	private var levelColor: Color {
		switch entry.level {
		case .info: return .primary
		case .success: return .green
		case .warning: return .orange
		case .error: return .red
		case .receive: return .blue
		case .send: return .purple
		case .event: return .cyan
		}
	}
	
	var body: some View {
		HStack(alignment: .top, spacing: 8) {
			Text(timeString)
				.font(.system(size: 11, design: .monospaced))
				.foregroundStyle(.secondary)
				.frame(width: 85, alignment: .leading)
			
			Text(entry.level.rawValue)
				.font(.system(size: 12))
			
			Text(entry.message)
				.font(.system(size: 12, design: .monospaced))
				.foregroundStyle(levelColor)
				.textSelection(.enabled)
		}
		.padding(.vertical, 2)
		.padding(.horizontal, 4)
		.background(
			entry.level == .error ? Color.red.opacity(0.1) :
			entry.level == .warning ? Color.orange.opacity(0.1) :
			Color.clear
		)
	}
}

#Preview {
	DebugView()
		.frame(width: 600, height: 400)
}
