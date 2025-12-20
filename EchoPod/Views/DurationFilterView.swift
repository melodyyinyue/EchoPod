import SwiftUI
import SwiftData

struct DurationFilterView: View {
	@Environment(\.modelContext) private var modelContext
	@EnvironmentObject private var player: PlayerController
	@EnvironmentObject private var downloads: EpisodeDownloadManager
	
	@Query(sort: \PodcastEpisode.publishedAt, order: .reverse)
	private var allEpisodes: [PodcastEpisode]
	
	@State private var targetMinutes: Int = 30
	@State private var toleranceMinutes: Int = 10
	@State private var isEditing: Bool = false
	
	private var filteredEpisodes: [PodcastEpisode] {
		let targetSeconds = targetMinutes * 60
		let toleranceSeconds = toleranceMinutes * 60
		let minSeconds = max(0, targetSeconds - toleranceSeconds)
		let maxSeconds = targetSeconds + toleranceSeconds
		
		return allEpisodes.filter { episode in
			guard let duration = episode.durationSeconds else { return false }
			return duration >= minSeconds && duration <= maxSeconds
		}
	}
	
	var body: some View {
		VStack(spacing: 0) {
			// 时长选择器
			durationPicker
			
			Divider()
			
			// 结果列表
			if filteredEpisodes.isEmpty {
				emptyState
			} else {
				resultsList
			}
		}
		.navigationTitle("按时长筛选")
	}
	
	// MARK: - Duration Picker
	@ViewBuilder
	private var durationPicker: some View {
		VStack(spacing: 16) {
			// 时间输入区
			HStack(spacing: 20) {
				// 目标时长
				VStack(alignment: .leading, spacing: 8) {
					HStack {
						Image(systemName: "clock.badge.checkmark")
							.font(.title3)
							.foregroundStyle(AppTheme.primary)
						Text("目标时长")
							.font(.headline)
					}
					
					HStack {
						Slider(value: Binding(
							get: { Double(targetMinutes) },
							set: { targetMinutes = Int($0) }
						), in: 5...180, step: 5) { editing in
							isEditing = editing
						}
						.tint(AppTheme.primary)
						.frame(width: 180)
						
						Text("\(targetMinutes) 分钟")
							.font(.system(.body, design: .rounded))
							.fontWeight(.semibold)
							.foregroundStyle(AppTheme.primary)
							.frame(width: 70, alignment: .trailing)
					}
				}
				
				Divider()
					.frame(height: 40)
				
				// 容差范围 - 紧凑的 Menu（不显示文字标签）
				VStack(alignment: .leading, spacing: 8) {
					Menu {
						ForEach([5, 10, 15, 20, 30], id: \.self) { minutes in
							Button {
								toleranceMinutes = minutes
							} label: {
								HStack {
									Text("±\(minutes) 分钟")
									if toleranceMinutes == minutes {
										Image(systemName: "checkmark")
									}
								}
							}
						}
					} label: {
						HStack(spacing: 4) {
							Text("±\(toleranceMinutes) 分钟")
								.font(.system(.body, design: .rounded))
								.fontWeight(.medium)
							Image(systemName: "chevron.up.chevron.down")
								.font(.caption2)
						}
						.padding(.horizontal, 12)
						.padding(.vertical, 6)
						.background(AppTheme.primary.opacity(0.1))
						.foregroundStyle(AppTheme.primary)
						.clipShape(RoundedRectangle(cornerRadius: 8))
					}
					.buttonStyle(.plain)
				}
			}
			
			// 筛选结果摘要
			HStack {
				if !filteredEpisodes.isEmpty {
					Text("找到 \(filteredEpisodes.count) 个播客")
						.font(.caption)
						.foregroundStyle(.secondary)
					
					Text("（\(formatDuration(max(0, targetMinutes - toleranceMinutes) * 60)) ~ \(formatDuration((targetMinutes + toleranceMinutes) * 60))）")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				
				// 快捷时长按钮
				HStack(spacing: 8) {
					ForEach([15, 30, 60, 90], id: \.self) { minutes in
						Button {
							withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
								targetMinutes = minutes
							}
						} label: {
							Text("\(minutes)分钟")
								.font(.caption)
								.padding(.horizontal, 10)
								.padding(.vertical, 6)
								.background(
									targetMinutes == minutes
									? AppTheme.primary.opacity(0.2)
									: Color(nsColor: .controlBackgroundColor)
								)
								.foregroundStyle(targetMinutes == minutes ? AppTheme.primary : .primary)
								.clipShape(Capsule())
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
		.padding(20)
		.background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
	}
	
	// MARK: - Results List
	@ViewBuilder
	private var resultsList: some View {
		List {
			ForEach(filteredEpisodes) { episode in
				NavigationLink(destination: EpisodeDetailView(episode: episode)) {
					EpisodeRow(episode: episode)
				}
			}
		}
		.listStyle(.inset)
	}
	
	// MARK: - Empty State
	@ViewBuilder
	private var emptyState: some View {
		VStack(spacing: 16) {
			Spacer()
			
			Image(systemName: "clock.badge.questionmark")
				.font(.system(size: 60))
				.foregroundStyle(.secondary.opacity(0.5))
			
			Text("没有找到符合条件的播客")
				.font(.headline)
				.foregroundStyle(.secondary)
			
			Text("尝试调整目标时长或增大容差范围")
				.font(.caption)
				.foregroundStyle(.secondary.opacity(0.7))
			
			// 建议
			if let closestEpisode = findClosestDurationEpisode() {
				VStack(spacing: 8) {
					Text("最接近的播客：")
						.font(.caption)
						.foregroundStyle(.secondary)
					
					HStack {
						Text(closestEpisode.title)
							.font(.subheadline)
							.lineLimit(1)
						
						if let duration = closestEpisode.durationSeconds {
							Text("(\(formatDuration(duration)))")
								.font(.caption)
								.foregroundStyle(AppTheme.primary)
						}
					}
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.background(AppTheme.primary.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 10))
				}
				.padding(.top, 20)
			}
			
			Spacer()
		}
		.frame(maxWidth: .infinity)
	}
	
	// MARK: - Helpers
	private func formatDuration(_ seconds: Int) -> String {
		let hours = seconds / 3600
		let minutes = (seconds % 3600) / 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		} else {
			return "\(minutes)m"
		}
	}
	
	private func findClosestDurationEpisode() -> PodcastEpisode? {
		let targetSeconds = targetMinutes * 60
		return allEpisodes
			.filter { $0.durationSeconds != nil }
			.min { abs(($0.durationSeconds ?? 0) - targetSeconds) < abs(($1.durationSeconds ?? 0) - targetSeconds) }
	}
}

#Preview {
	DurationFilterView()
}
