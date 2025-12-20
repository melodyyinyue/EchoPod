import SwiftUI

/// 脚本列表视图
struct ScriptListView: View {
	let script: String
	@EnvironmentObject private var player: PlayerController
	
	/// 解析脚本为段落数组
	private var segments: [Segment] {
		script.components(separatedBy: "\n\n")
			.filter { !$0.isEmpty }
			.map { line in
				if line.hasPrefix("【") {
					if let endIndex = line.firstIndex(of: "】") {
						let speaker = String(line[line.index(after: line.startIndex)..<endIndex])
						let text = String(line[line.index(after: endIndex)...])
						return Segment(speaker: speaker, text: text.trimmingCharacters(in: .whitespaces))
					}
				}
				return Segment(speaker: nil, text: line)
			}
	}
	
	struct Segment: Identifiable {
		let id = UUID()
		let speaker: String?
		let text: String
	}
	
	private func formatSpeakerName(_ raw: String) -> String {
		if raw.contains("liufei") { return "刘飞" }
		if raw.contains("xiaolei") { return "潇磊" }
		if raw.contains("zh_male") { return "男主播" }
		if raw.contains("zh_female") { return "女主播" }
		return raw
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Image(systemName: "text.bubble")
					.foregroundStyle(AppTheme.primary)
				Text("播客内容")
					.font(.headline)
			}
			.padding(.horizontal)

			ScrollView {
				LazyVStack(alignment: .leading, spacing: 20) {
					ForEach(Array(segments.enumerated()), id: \.element.id) { index, segment in
						Button {
							seekToSegment(index: index)
						} label: {
							VStack(alignment: .leading, spacing: 6) {
								if let speaker = segment.speaker {
									HStack(spacing: 6) {
										Image(systemName: "person.circle.fill")
											.foregroundStyle(AppTheme.primary.opacity(0.8))
											.font(.caption)
										Text(formatSpeakerName(speaker))
											.font(.caption)
											.fontWeight(.bold)
											.foregroundStyle(AppTheme.primary)
									}
								}
								
								Text(segment.text)
									.font(.body)
									.lineSpacing(6)
									.multilineTextAlignment(.leading)
									.foregroundStyle(.primary.opacity(0.9))
							}
							.padding(.horizontal)
							.padding(.vertical, 4)
							.contentShape(Rectangle()) // 扩大点击区域
						}
						.buttonStyle(.plain)
					}
				}
				.padding(.bottom, 20)
			}
			.frame(maxHeight: 500) // 限制高度，允许内部滚动
			.background(AppTheme.background.opacity(0.3))
			.clipShape(RoundedRectangle(cornerRadius: 12))
		}
	}
	
	private func seekToSegment(index: Int) {
		// 简单的估算跳转：假设每个字符的语速大致相同
		// 计算目标段落之前的总字符数
		let totalChars = segments.reduce(0) { $0 + $1.text.count }
		guard totalChars > 0 else { return }
		
		let previousChars = segments.prefix(index).reduce(0) { $0 + $1.text.count }
		
		// 获取当前音频总时长
		let duration = player.duration
		guard duration > 0 else { return }
		
		// 估算目标时间点
		let targetTime = duration * (Double(previousChars) / Double(totalChars))
		
		// 跳转
		player.seek(to: targetTime)
	}
}
