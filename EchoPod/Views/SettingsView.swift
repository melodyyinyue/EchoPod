import SwiftUI
import SwiftData

struct SettingsView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(filter: #Predicate<AppSettings> { $0.id == "singleton" })
	private var settings: [AppSettings]

	@State private var podcastAppID: String = ""
	@State private var podcastAccessToken: String = ""
	@State private var podcastResourceID: String = "volc.service_type.10050"

	@State private var coverKey: String = ""
	@State private var coverBaseURL: String = "https://ark.cn-beijing.volces.com"
	
	@State private var showSaveSuccess: Bool = false

	var body: some View {
		Form {
			Section("播客生成（WebSocket）") {
				TextField("APP ID", text: $podcastAppID)
				SecureField("Access Token", text: $podcastAccessToken)
				TextField("Resource ID", text: $podcastResourceID)
			}

			Section("封面生成") {
				SecureField("封面生成 API Key", text: $coverKey)
				TextField("封面生成 Base URL", text: $coverBaseURL)
					.textContentType(.URL)
				
				// 提示当前推荐 URL
				Text("推荐使用: https://ark.cn-beijing.volces.com")
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Section {
				HStack {
					Button("保存") {
						save()
					}
					.buttonStyle(.borderedProminent)
					
					if showSaveSuccess {
						Label("已保存", systemImage: "checkmark.circle.fill")
							.foregroundStyle(.green)
							.font(.caption)
					}
				}
				
				// 显示当前数据库中保存的值
				if let s = settings.first {
					VStack(alignment: .leading, spacing: 4) {
						Text("当前已保存配置:")
							.font(.caption)
							.foregroundStyle(.secondary)
						Text("Base URL: \(s.volcCoverBaseURL ?? "未设置")")
							.font(.caption2)
							.foregroundStyle(.secondary)
						Text("API Key: \(s.volcCoverAPIKey?.isEmpty == false ? "已设置" : "未设置")")
							.font(.caption2)
							.foregroundStyle(.secondary)
					}
				}
			}
		}
		.padding()
		.onAppear { load() }
	}

	private func load() {
		let s = settings.first ?? {
			let created = AppSettings()
			modelContext.insert(created)
			return created
		}()
		podcastAppID = s.volcPodcastAppID ?? ""
		podcastAccessToken = s.volcPodcastAccessToken ?? ""
		podcastResourceID = s.volcPodcastResourceID ?? "volc.service_type.10050"
		coverKey = s.volcCoverAPIKey ?? ""
		// 如果数据库有值就用，没有就用默认值
		coverBaseURL = s.volcCoverBaseURL ?? "https://ark.cn-beijing.volces.com"
	}

	private func save() {
		let s = settings.first ?? {
			let created = AppSettings()
			modelContext.insert(created)
			return created
		}()
		s.volcPodcastAppID = podcastAppID.isEmpty ? nil : podcastAppID
		s.volcPodcastAccessToken = podcastAccessToken.isEmpty ? nil : podcastAccessToken
		s.volcPodcastResourceID = podcastResourceID.isEmpty ? nil : podcastResourceID
		s.volcCoverAPIKey = coverKey.isEmpty ? nil : coverKey
		// Base URL 保存时，使用默认值而不是 nil
		s.volcCoverBaseURL = coverBaseURL.isEmpty ? "https://ark.cn-beijing.volces.com" : coverBaseURL
		s.updatedAt = Date()
		try? modelContext.save()
		
		// 显示保存成功
		withAnimation {
			showSaveSuccess = true
		}
		DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
			withAnimation {
				showSaveSuccess = false
			}
		}
	}
}

