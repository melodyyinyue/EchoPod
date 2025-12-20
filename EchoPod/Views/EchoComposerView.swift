import SwiftUI
import SwiftData

struct EchoComposerView: View {
	@Environment(\.modelContext) private var modelContext

	@Query(filter: #Predicate<AppSettings> { $0.id == "singleton" })
	private var settings: [AppSettings]

	@State private var question: String = ""
	@State private var isGenerating = false
	@State private var statusText: String?
	@State private var currentEcho: EchoPodcast?
	@StateObject private var streamingPlayer = StreamingAudioPlayer()

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("回音播客")
				.font(.headline)

			TextField("输入你感兴趣的问题…", text: $question, axis: .vertical)
				.lineLimit(3...6)
				.textFieldStyle(.roundedBorder)

			if let statusText {
				Text(statusText)
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			
			// 流式播放控件
			if streamingPlayer.isStreaming || streamingPlayer.isPlaying || streamingPlayer.bufferedDuration > 0 {
				StreamingPlayerView(player: streamingPlayer)
			}

			HStack {
				Button(isGenerating ? "生成中..." : "生成") {
					Task { @MainActor in await generate() }
				}
				.disabled(isGenerating)

				if let currentEcho, currentEcho.status == "completed" {
					Spacer()
					NavigationLink {
						EchoPodcastDetailView(item: currentEcho)
					} label: {
						Text("查看详情")
					}
				}
			}
		}
		.frame(width: 360)
		.padding(12)
	}

	@MainActor
	private func generate() async {
		statusText = nil
		currentEcho = nil
		streamingPlayer.stop()

		let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !q.isEmpty else {
			statusText = "请输入问题"
			return
		}

		let s = settings.first ?? {
			let created = AppSettings()
			modelContext.insert(created)
			return created
		}()

		guard let appID = s.volcPodcastAppID, !appID.isEmpty,
			  let token = s.volcPodcastAccessToken, !token.isEmpty else {
			statusText = "请先在【设置】里填写播客生成的 APP ID 和 Access Token"
			return
		}

		isGenerating = true
		defer { isGenerating = false }

		// 立刻创建播客记录（状态为 generating）
		let taskID = UUID().uuidString
		let title = q.count > 24 ? String(q.prefix(24)) + "…" : q
		let echo = EchoPodcast(id: taskID, question: q, title: title, status: "generating")
		echo.statusMessage = "准备连接..."
		modelContext.insert(echo)
		try? modelContext.save()
		currentEcho = echo

		// 开始流式播放
		streamingPlayer.startStreaming()

		do {
			let resourceID = s.volcPodcastResourceID ?? "volc.service_type.10050"
			let client = VolcPodcastTTSWebSocketClient(appID: appID, accessToken: token, resourceID: resourceID)
			
			debugLog("开始调用 generatePodcastFromPrompt...", level: .info)
			let (returnedTaskID, audioURL, localFileURL) = try await client.generatePodcastFromPrompt(
				promptText: q,
				inputID: "echopod_\(taskID)",
				useHeadMusic: false,
				audioFormat: "mp3",
				saveToLocalMP3: true,
				onStatus: { text in
					Task { @MainActor in
						statusText = text
					}
				},
				onAudioData: { data in
					Task { @MainActor in
						streamingPlayer.appendAudioData(data)
					}
				}
			)
			
			// 流式接收完成
			streamingPlayer.finishStreaming()
			
			debugLog("生成完成! taskID=\(returnedTaskID), audioURL=\(audioURL), localFile=\(localFileURL?.path ?? "nil")", level: .success)

			// 生成封面
			var coverURL: String?
			if let coverKey = s.volcCoverAPIKey, !coverKey.isEmpty {
				statusText = "生成封面中..."
				echo.statusMessage = "生成封面中..."
				try? modelContext.save()
				
				let coverClient = VolcEchoClient(podcastAPIKey: "", coverAPIKey: coverKey)
				coverURL = try? await coverClient.generateCover(prompt: "播客封面：\(q)")
				debugLog("封面生成结果: \(coverURL ?? "nil")", level: .info)
			}

			// 更新播客记录为完成状态
			debugLog("更新 echo 状态为 completed...", level: .info)
			echo.audioURL = audioURL
			echo.coverURL = coverURL
			echo.status = "completed"
			echo.statusMessage = nil
			if let localFileURL {
				echo.localFilePath = localFileURL.path
				echo.downloadedAt = Date()
			}
			try? modelContext.save()
			debugLog("echo 已保存, status=\(echo.status), audioURL=\(echo.audioURL ?? "nil")", level: .success)

			statusText = (echo.localFilePath == nil) ? "生成完成（音频链接有效期约 1h）" : "生成完成（已离线保存）"
		} catch {
			streamingPlayer.stop()
			
			// 更新播客记录为失败状态
			echo.status = "failed"
			echo.errorMessage = error.localizedDescription
			echo.statusMessage = nil
			try? modelContext.save()
			
			statusText = "生成失败：\(error.localizedDescription)"
		}
	}
}

// MARK: - Streaming Player View

struct StreamingPlayerView: View {
	@ObservedObject var player: StreamingAudioPlayer
	
	var body: some View {
		VStack(spacing: 8) {
			// 进度条
			HStack(spacing: 8) {
				Text(formatTime(player.currentTime))
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
				
				GeometryReader { geo in
					ZStack(alignment: .leading) {
						// 背景
						Capsule()
							.fill(Color.gray.opacity(0.2))
							.frame(height: 4)
						
						// 缓冲进度
						if player.bufferedDuration > 0 && player.duration > 0 {
							Capsule()
								.fill(Color.blue.opacity(0.3))
								.frame(width: geo.size.width * min(1, player.bufferedDuration / player.duration), height: 4)
						}
						
						// 播放进度
						if player.duration > 0 {
							Capsule()
								.fill(Color.blue)
								.frame(width: geo.size.width * min(1, player.currentTime / player.duration), height: 4)
						}
					}
				}
				.frame(height: 4)
				
				Text(formatTime(player.duration))
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
			}
			
			// 播放控制
			HStack(spacing: 16) {
				if player.isBuffering {
					ProgressView()
						.controlSize(.small)
					Text("缓冲中...")
						.font(.caption)
						.foregroundStyle(.secondary)
				} else {
					Button {
						player.togglePlayPause()
					} label: {
						Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
							.font(.title2)
					}
					.buttonStyle(.plain)
					
					if player.isStreaming {
						Text("边生成边播放")
							.font(.caption)
							.foregroundStyle(.orange)
					}
				}
				
				Spacer()
				
				// 已缓冲大小
				if player.bufferedDuration > 0 {
					Text("已缓冲 \(formatBytes(Int(player.bufferedDuration * 24000 * 2)))")
						.font(.caption2)
						.foregroundStyle(.secondary)
				}
			}
		}
		.padding(10)
		.background(Color(nsColor: .controlBackgroundColor))
		.cornerRadius(8)
	}
	
	private func formatTime(_ time: TimeInterval) -> String {
		let minutes = Int(time) / 60
		let seconds = Int(time) % 60
		return String(format: "%d:%02d", minutes, seconds)
	}
	
	private func formatBytes(_ bytes: Int) -> String {
		if bytes < 1024 {
			return "\(bytes) B"
		} else if bytes < 1024 * 1024 {
			return String(format: "%.1f KB", Double(bytes) / 1024)
		} else {
			return String(format: "%.1f MB", Double(bytes) / 1024 / 1024)
		}
	}
}
