import SwiftUI
import SwiftData

struct EchoPodcastDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@EnvironmentObject private var player: PlayerController
	@Bindable var item: EchoPodcast

	private var remoteURL: URL? {
		guard let urlString = item.audioURL else { return nil }
		return URL(string: urlString)
	}
	private var localURL: URL? {
		guard let p = item.localFilePath else { return nil }
		let url = URL(fileURLWithPath: p)
		return FileManager.default.fileExists(atPath: url.path) ? url : nil
	}
	private var effectiveURL: URL? { localURL ?? remoteURL }

	private var isCurrent: Bool {
		guard let effectiveURL else { return false }
		return player.currentURL == effectiveURL
	}

	var body: some View {
		ScrollView {
			VStack(alignment: .leading, spacing: 12) {
				HStack(alignment: .top, spacing: 12) {
					// 封面图
					coverImage
						.frame(width: 100, height: 100)
						.clipShape(RoundedRectangle(cornerRadius: 12))

					VStack(alignment: .leading, spacing: 6) {
						Text(item.title)
							.font(.title2)
							.bold()
						
						// 状态标签
						statusBadge
						
						Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					Spacer()
				}

				Text("问题")
					.font(.headline)
				Text(item.question)
					.textSelection(.enabled)

				// 生成中显示进度
				if item.isGenerating {
					VStack(spacing: 8) {
						ProgressView()
						if let msg = item.statusMessage {
							Text(msg)
								.font(.caption)
								.foregroundStyle(.secondary)
						}
					}
					.frame(maxWidth: .infinity)
					.padding()
					.background(Color.orange.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 8))
				}
				
				// 失败显示错误
				if item.isFailed, let err = item.errorMessage {
					VStack(alignment: .leading, spacing: 4) {
						Label("生成失败", systemImage: "exclamationmark.triangle.fill")
							.foregroundStyle(.red)
							.font(.headline)
						Text(err)
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					.padding()
					.frame(maxWidth: .infinity, alignment: .leading)
					.background(Color.red.opacity(0.1))
					.clipShape(RoundedRectangle(cornerRadius: 8))
				}

				// 播放控制（仅在完成时显示）
				if item.isCompleted {
					HStack(spacing: 12) {
						Button {
							guard let url = effectiveURL else { return }
							if isCurrent {
								player.togglePlayPause()
							} else {
								player.play(url: url)
							}
						} label: {
							Label(isCurrent && player.isPlaying ? "暂停" : "播放", systemImage: isCurrent && player.isPlaying ? "pause.fill" : "play.fill")
						}
						.disabled(effectiveURL == nil)
						.buttonStyle(.borderedProminent)

						if localURL != nil {
							Button(role: .destructive) {
								deleteLocal()
							} label: {
								Label("删除离线文件", systemImage: "trash")
							}
						}
					}
				}
			}
			.padding()
		}
		.navigationTitle("回音播客")
	}
	
	@ViewBuilder
	private var coverImage: some View {
		if let cover = item.coverURL, let coverURL = URL(string: cover) {
			AsyncImage(url: coverURL) { phase in
				switch phase {
				case .empty:
					ProgressView().frame(width: 100, height: 100)
				case .success(let image):
					image.resizable().scaledToFill()
				case .failure:
					defaultCover
				@unknown default:
					EmptyView()
				}
			}
		} else {
			defaultCover
		}
	}
	
	private var defaultCover: some View {
		ZStack {
			LinearGradient(
				colors: [.purple.opacity(0.6), .blue.opacity(0.6)],
				startPoint: .topLeading,
				endPoint: .bottomTrailing
			)
			Image(systemName: item.isGenerating ? "waveform" : "mic.fill")
				.foregroundStyle(.white)
				.font(.largeTitle)
		}
	}
	
	@ViewBuilder
	private var statusBadge: some View {
		if item.isGenerating {
			HStack(spacing: 4) {
				ProgressView()
					.scaleEffect(0.7)
				Text("生成中")
			}
			.font(.caption)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(Color.orange.opacity(0.2))
			.clipShape(Capsule())
		} else if item.isFailed {
			Label("失败", systemImage: "xmark.circle.fill")
				.font(.caption)
				.foregroundStyle(.red)
				.padding(.horizontal, 8)
				.padding(.vertical, 4)
				.background(Color.red.opacity(0.1))
				.clipShape(Capsule())
		} else if item.localFilePath != nil {
			Label("已离线", systemImage: "arrow.down.circle.fill")
				.font(.caption)
				.foregroundStyle(.green)
				.padding(.horizontal, 8)
				.padding(.vertical, 4)
				.background(Color.green.opacity(0.1))
				.clipShape(Capsule())
		}
	}

	private func deleteLocal() {
		guard let path = item.localFilePath else { return }
		do {
			try EchoPodcastCacheService.removeCachedFile(atPath: path)
			item.localFilePath = nil
			item.downloadedAt = nil
			try? modelContext.save()
		} catch {
			// 最小实现：先不弹窗
		}
	}
}
