import SwiftUI
import SwiftData

struct EchoComposerView: View {
	@Environment(\.modelContext) private var modelContext

	@Query(filter: #Predicate<AppSettings> { $0.id == "singleton" })
	private var settings: [AppSettings]

	@State private var question: String = ""
	@State private var isGenerating = false
	@State private var statusText: String?
	@State private var lastGenerated: EchoPodcast?

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
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

			HStack {
				Button(isGenerating ? "生成中..." : "生成") {
					Task { @MainActor in await generate() }
				}
				.disabled(isGenerating)

				if let lastGenerated {
					Spacer()
					NavigationLink {
						EchoPodcastDetailView(item: lastGenerated)
					} label: {
						Text("查看")
					}
				}
			}
		}
		.frame(width: 340)
		.padding(12)
	}

	@MainActor
	private func generate() async {
		statusText = nil
		lastGenerated = nil

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

		do {
			let resourceID = s.volcPodcastResourceID ?? "volc.service_type.10050"
			let client = VolcPodcastTTSWebSocketClient(appID: appID, accessToken: token, resourceID: resourceID)
			let (taskID, audioURL) = try await client.generatePodcastFromPrompt(
				promptText: q,
				inputID: "echopod_\(UUID().uuidString)",
				useHeadMusic: false,
				onStatus: { text in
					Task { @MainActor in
						statusText = text
					}
				}
			)

			var coverURL: String?
			if let coverKey = s.volcCoverAPIKey, !coverKey.isEmpty {
				let coverClient = VolcEchoClient(podcastAPIKey: "", coverAPIKey: coverKey)
				coverURL = try await coverClient.generateCover(prompt: "播客封面：\(q)")
			}

			let title = q.count > 24 ? String(q.prefix(24)) + "…" : q
			let echo = EchoPodcast(id: taskID, question: q, title: title, audioURL: audioURL, coverURL: coverURL)
			modelContext.insert(echo)
			try? modelContext.save()

			lastGenerated = echo
			statusText = "生成完成（音频链接有效期约 1h）"
		} catch {
			statusText = "生成失败：\(error.localizedDescription)"
		}
	}
}
