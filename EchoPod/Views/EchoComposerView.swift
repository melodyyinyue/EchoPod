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

			TextField("输入你想了解的知识、概念、问题…", text: $question, axis: .vertical)
				.lineLimit(3...6)
				.textFieldStyle(.roundedBorder)
			
			// 流式播放控件
			if streamingPlayer.isStreaming || streamingPlayer.isPlaying || streamingPlayer.bufferedDuration > 0 {
				StreamingPlayerView(player: streamingPlayer)
			}

			// 状态文本显示
			if let statusText {
				HStack {
					if statusText.contains("失败") || statusText.contains("请先") || statusText.contains("请输入") {
						Image(systemName: "exclamationmark.triangle.fill")
							.foregroundStyle(.orange)
					} else {
						Image(systemName: "info.circle.fill")
							.foregroundStyle(.blue)
					}
					Text(statusText)
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				.padding(8)
				.frame(maxWidth: .infinity, alignment: .leading)
				.background(Color(nsColor: .controlBackgroundColor))
				.cornerRadius(6)
			}

			HStack {

				Spacer()
				
				Button(isGenerating ? "生成中..." : "生成") {
					Task { @MainActor in await generate() }
				}
				.buttonStyle(.borderedProminent)
				.tint(AppTheme.primary)
				.disabled(isGenerating)
			}
		}
		.frame(width: 360)
		.padding(12)
	}

	@MainActor
	private func generate() async {
		debugLog("=== 开始生成播客 ===", level: .info)
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

		debugLog("检查配置: appID=\(s.volcPodcastAppID?.prefix(8) ?? "nil")..., token=\(s.volcPodcastAccessToken?.isEmpty == false ? "已设置" : "未设置")", level: .info)
		
		guard let appID = s.volcPodcastAppID, !appID.isEmpty,
			  let token = s.volcPodcastAccessToken, !token.isEmpty else {
			debugLog("配置检查失败：APP ID 或 Access Token 未设置", level: .warning)
			statusText = "请先在【设置】里填写播客生成的 APP ID 和 Access Token"
			return
		}
		
		debugLog("配置检查通过，开始生成...", level: .success)

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

		// 更新共享播放信息（让状态栏显示正确的标题）
		CurrentPlayingInfo.shared.setEchoPodcast(title: title, coverURL: nil)
		defer { CurrentPlayingInfo.shared.clearEchoPodcast() }
		
		// 开始流式播放
		streamingPlayer.startStreaming()

		do {
			let resourceID = s.volcPodcastResourceID ?? "volc.service_type.10050"
			let client = VolcPodcastTTSWebSocketClient(appID: appID, accessToken: token, resourceID: resourceID)
			
			// 收集脚本内容
			var scriptSegments: [(speaker: String, text: String)] = []
			
			// 获取用户选择的主讲人
			let speakers = s.speakerPair.speakers
			debugLog("使用主讲人: \(s.speakerPair.displayName) - \(speakers)", level: .info)
			
			debugLog("开始调用 generatePodcastFromPrompt...", level: .info)
			let (returnedTaskID, audioURL, localFileURL) = try await client.generatePodcastFromPrompt(
				promptText: q,
				inputID: "echopod_\(taskID)",
				useHeadMusic: false,
				speakers: speakers,
				audioFormat: "mp3",
				saveToLocalMP3: true,
				onStatus: { text in
					Task { @MainActor in
						// 过滤掉包含技术信息的状态文本
						if text.contains("zh_male") || text.contains("zh_female") ||
						   text.contains("saturn") || text.contains("bigtts") ||
						   text.contains("dayixiansheng") || text.contains("_v2_") {
							// 不显示包含模型 ID 的技术信息
							return
						}
						statusText = text
					}
				},
				onAudioData: { data in
					Task { @MainActor in
						streamingPlayer.appendAudioData(data)
					}
				},
				onScript: { speaker, text in
					Task { @MainActor in
						scriptSegments.append((speaker: speaker, text: text))
					}
				}
			)
			
			// 流式接收完成
			streamingPlayer.finishStreaming()
			
			// 将脚本段落合并为完整脚本内容
			let fullScript = scriptSegments.map { segment in
				if segment.speaker.isEmpty {
					return segment.text
				} else {
					return "【\(segment.speaker)】\(segment.text)"
				}
			}.joined(separator: "\n\n")
			echo.scriptContent = fullScript
			
			debugLog("生成完成! taskID=\(returnedTaskID), audioURL=\(audioURL), localFile=\(localFileURL?.path ?? "nil"), script=\(fullScript.prefix(100))...", level: .success)

				// 生成封面
			var coverURL: String?
			if let coverKey = s.volcCoverAPIKey, !coverKey.isEmpty {
				statusText = "生成封面中..."
				echo.statusMessage = "生成封面中..."
				try? modelContext.save()
				
				let base = URL(string: s.volcCoverBaseURL ?? "https://ark.cn-beijing.volces.com")
				debugLog("封面生成配置: baseURL=\(base?.absoluteString ?? "nil"), keyLength=\(coverKey.count)", level: .info)
				
				let coverClient = VolcEchoClient(podcastAPIKey: "", coverAPIKey: coverKey, coverBaseURL: base)
				// 优化的封面 Prompt：主题 + 艺术风格
				let coverPrompt = """
播客封面：\(q)，
现代简约风格，渐变紫色背景，柔和光影，
高级质感，抽象几何元素，细腻纹理，
专业播客封面设计，高清画质
"""
				debugLog("封面 Prompt: \(coverPrompt.prefix(50))...", level: .send)
				
				do {
					coverURL = try await coverClient.generateCover(prompt: coverPrompt)
					if let urlString = coverURL, let remoteURL = URL(string: urlString) {
						debugLog("封面生成成功: \(urlString)", level: .success)
						
						// 立即更新封面 URL，让 UI 先显示网络图片
						echo.coverURL = urlString
						try? modelContext.save()
						
						// 下载封面图片并保存
						do {
							let (data, _) = try await URLSession.shared.data(from: remoteURL)
							let localCover = try EchoPodcastCacheService.localCoverURL(taskID: taskID)
							try data.write(to: localCover)
							echo.localCoverPath = localCover.path
                            try? modelContext.save()
							debugLog("封面已保存到本地: \(localCover.path)", level: .success)
						} catch {
							debugLog("封面保存失败: \(error.localizedDescription)", level: .warning)
						}
					} else {
						debugLog("封面生成返回空结果", level: .warning)
					}
				} catch {
					debugLog("封面生成失败: \(error.localizedDescription)", level: .error)
				}
			} else {
				debugLog("跳过封面生成: API Key 未设置", level: .warning)
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
