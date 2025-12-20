import SwiftUI
import SwiftData

struct EpisodeDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@EnvironmentObject private var player: PlayerController
	@EnvironmentObject private var downloads: EpisodeDownloadManager
	let episode: PodcastEpisode

	@State private var cacheError: String?
	@State private var isHoveringPlay: Bool = false

	private var remoteURL: URL? {
		URL(string: episode.audioURL)
	}

	private var localURL: URL? {
		guard let p = episode.localFilePath else { return nil }
		let url = URL(fileURLWithPath: p)
		return FileManager.default.fileExists(atPath: url.path) ? url : nil
	}

	private var effectiveURL: URL? {
		localURL ?? remoteURL
	}

	private var isCurrent: Bool {
		guard let effectiveURL else { return false }
		return player.currentURL == effectiveURL
	}

	private var currentTimeBinding: Binding<Double> {
		Binding(
			get: { isCurrent ? player.currentTime : 0 },
			set: { newValue in
				guard isCurrent else { return }
				player.seek(to: newValue)
			}
		)
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 0) {
				// 顶部封面区域 - 渐变背景
				headerSection
				
				// 内容区域
				VStack(alignment: .leading, spacing: 20) {
					// 快捷操作按钮（不含播放控制，使用底部全局播放条）
					quickActionsSection
					
					// Shownotes 摘要
					shownotesSection
				}
				.padding(.horizontal, 20)
				.padding(.top, 16)
				.padding(.bottom, 100) // 为底部全局播放条留空间
			}
		}
		.background(Color(nsColor: .windowBackgroundColor))
		.navigationTitle("")
	}
	
	// MARK: - Header Section
	@ViewBuilder
	private var headerSection: some View {
		ZStack(alignment: .bottom) {
			// 背景渐变
			GeometryReader { geo in
				AsyncImage(url: coverURL(for: episode)) { phase in
					switch phase {
					case .success(let img):
						img.resizable()
							.aspectRatio(contentMode: .fill)
							.frame(width: geo.size.width, height: 280)
							.blur(radius: 30)
							.overlay(
								LinearGradient(
									colors: [
										Color.black.opacity(0.3),
										Color.black.opacity(0.6),
										Color(nsColor: .windowBackgroundColor)
									],
									startPoint: .top,
									endPoint: .bottom
								)
							)
					default:
						LinearGradient(
							colors: [AppTheme.primary.opacity(0.4), .blue.opacity(0.3), Color(nsColor: .windowBackgroundColor)],
							startPoint: .topLeading,
							endPoint: .bottom
						)
					}
				}
				.frame(height: 280)
			}
			.frame(height: 280)
			
			// 内容
			HStack(alignment: .bottom, spacing: 20) {
				// 封面
				AsyncImage(url: coverURL(for: episode)) { phase in
					switch phase {
					case .success(let img):
						img.resizable()
							.aspectRatio(contentMode: .fill)
					default:
						ZStack {
							LinearGradient(
								colors: [AppTheme.primary.opacity(0.6), .blue.opacity(0.6)],
								startPoint: .topLeading,
								endPoint: .bottomTrailing
							)
							Image(systemName: "mic.fill")
								.foregroundStyle(.white.opacity(0.8))
								.font(.system(size: 40))
						}
					}
				}
				.frame(width: 140, height: 140)
				.clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
				.shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 6)
				
				// 标题和元信息
				VStack(alignment: .leading, spacing: 8) {
					if let name = episode.feed?.title, !name.isEmpty {
						Text(name.uppercased())
							.font(.caption)
							.fontWeight(.semibold)
							.foregroundStyle(.white.opacity(0.9))
							.tracking(1)
					}
					
					Text(episode.title)
						.font(.title2)
						.fontWeight(.bold)
						.foregroundStyle(.white)
						.lineLimit(3)
						.multilineTextAlignment(.leading)
					
					HStack(spacing: 12) {
						if let date = episode.publishedAt {
							Label(date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
								.font(.caption)
								.foregroundStyle(.white.opacity(0.8))
						}
						
						if let duration = episode.durationSeconds, duration > 0 {
							Label(formatDuration(duration), systemImage: "clock")
								.font(.caption)
								.foregroundStyle(.white.opacity(0.8))
						}
						
						if localURL != nil {
							Label("已缓存", systemImage: "arrow.down.circle.fill")
								.font(.caption)
								.foregroundStyle(.green)
						}
					}
				}
				
				Spacer()
			}
			.padding(.horizontal, 20)
			.padding(.bottom, 20)
		}
	}
	
	// MARK: - Quick Actions Section (简化，播放使用全局播放条)
	@ViewBuilder
	private var quickActionsSection: some View {
		VStack(spacing: 12) {
			// 错误提示
			if let cacheError {
				HStack {
					Image(systemName: "exclamationmark.triangle.fill")
						.foregroundStyle(.orange)
					Text(cacheError)
						.font(.caption)
						.foregroundStyle(.secondary)
					Spacer()
					Button {
						self.cacheError = nil
					} label: {
						Image(systemName: "xmark.circle.fill")
							.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
				}
				.padding(12)
				.background(Color.orange.opacity(0.1))
				.clipShape(RoundedRectangle(cornerRadius: 10))
			}
			
			// 快捷操作
			HStack(spacing: 12) {
				// 播放按钮（触发全局播放）
				Button {
					guard let url = effectiveURL else { return }
					if isCurrent { player.togglePlayPause() } else { player.play(url: url) }
				} label: {
					Label(isCurrent && player.isPlaying ? "暂停" : "播放", systemImage: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
						.font(.subheadline)
						.fontWeight(.medium)
				}
				.buttonStyle(.borderedProminent)
				.tint(AppTheme.primary)
				.disabled(effectiveURL == nil)
				
				// 下载/缓存按钮
				Button {
					Task { @MainActor in await toggleCache() }
				} label: {
					if downloads.isDownloading(guid: episode.guid) {
						HStack(spacing: 6) {
							ProgressView()
								.controlSize(.small)
							Text("下载中...")
								.font(.caption)
						}
					} else {
						Label(localURL != nil ? "删除缓存" : "下载离线", systemImage: localURL != nil ? "trash" : "arrow.down.circle")
							.font(.subheadline)
					}
				}
				.buttonStyle(.bordered)
				.tint(localURL != nil ? .red : .secondary)
				.disabled(remoteURL == nil)
				
				Spacer()
			}
		}
		.padding(16)
		.background(
			RoundedRectangle(cornerRadius: 12, style: .continuous)
				.fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
		)
	}
	
	// MARK: - Shownotes Section
	@ViewBuilder
	private var shownotesSection: some View {
		if let summary = episode.summary, !summary.isEmpty {
			VStack(alignment: .leading, spacing: 12) {
				HStack {
					Image(systemName: "doc.text")
						.foregroundStyle(AppTheme.primary)
					Text("节目简介")
						.font(.headline)
					Spacer()
				}
				
				Divider()
				
				if let attr = htmlToAttributed(summary) {
					Text(attr)
						.font(.body)
						.lineSpacing(6)
						.textSelection(.enabled)
				} else {
					Text(summary)
						.font(.body)
						.lineSpacing(6)
						.textSelection(.enabled)
						.foregroundStyle(.secondary)
				}
			}
			.padding(20)
			.background(
				RoundedRectangle(cornerRadius: 16, style: .continuous)
					.fill(Color(nsColor: .controlBackgroundColor).opacity(0.3))
			)
		}
	}

	@MainActor
	private func toggleCache() async {
		cacheError = nil

		if let path = episode.localFilePath, !path.isEmpty {
			do {
				try EpisodeCacheService.removeCachedFile(atPath: path)
				episode.localFilePath = nil
				episode.downloadedAt = nil
				try? modelContext.save()
			} catch {
				cacheError = "删除缓存失败：\(error.localizedDescription)"
			}
			return
		}

		guard let remoteURL else {
			cacheError = "音频链接无效"
			return
		}

		if downloads.isDownloading(guid: episode.guid) {
			downloads.cancelDownload(guid: episode.guid)
			return
		}

		downloads.startDownload(remoteURL: remoteURL, guid: episode.guid) { result in
			switch result {
			case .success(let dest):
				episode.localFilePath = dest.path
				episode.downloadedAt = Date()
				try? modelContext.save()
			case .failure(let error):
				cacheError = "缓存失败：\(error.localizedDescription)"
			}
		}
	}

	private func formatTime(_ seconds: Double) -> String {
		guard seconds.isFinite, seconds > 0 else { return "0:00" }
		let total = Int(seconds.rounded())
		let m = total / 60
		let s = total % 60
		return String(format: "%d:%02d", m, s)
	}
	
	private func formatDuration(_ seconds: Int) -> String {
		let hours = seconds / 3600
		let minutes = (seconds % 3600) / 60
		if hours > 0 {
			return "\(hours)小时\(minutes)分钟"
		} else {
			return "\(minutes)分钟"
		}
	}

	private func htmlToAttributed(_ html: String) -> AttributedString? {
		guard let data = html.data(using: .utf8) else { return nil }
		let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
			.documentType: NSAttributedString.DocumentType.html,
			.characterEncoding: String.Encoding.utf8.rawValue
		]
		if let nsAttr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) {
			return AttributedString(nsAttr)
		}
		return nil
	}

	private func coverURL(for episode: PodcastEpisode) -> URL? {
		if let s = episode.imageURL, let u = URL(string: s) { return u }
		if let s = episode.feed?.imageURL, let u = URL(string: s) { return u }
		return nil
	}
}
