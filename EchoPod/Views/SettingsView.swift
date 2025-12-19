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

	var body: some View {
		Form {
			Section("播客生成（WebSocket）") {
				TextField("APP ID", text: $podcastAppID)
				SecureField("Access Token", text: $podcastAccessToken)
				TextField("Resource ID", text: $podcastResourceID)
			}

			Section("封面生成") {
				SecureField("封面生成 API Key", text: $coverKey)
			}

			Section {
				Button("保存") {
					save()
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
		s.updatedAt = Date()
		try? modelContext.save()
	}
}
