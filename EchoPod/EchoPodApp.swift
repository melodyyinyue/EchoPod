import SwiftUI
import SwiftData

@main
struct EchoPodApp: App {
	private let modelContainer: ModelContainer
	@StateObject private var player = PlayerController()
	@StateObject private var downloads = EpisodeDownloadManager()

	init() {
		do {
			modelContainer = try ModelContainer(for: PodcastFeed.self, PodcastEpisode.self, EchoPodcast.self, AppSettings.self, CoverDesignHistory.self)
		} catch {
			fatalError("Failed to create ModelContainer: \(error)")
		}
	}

	var body: some Scene {
		WindowGroup {
			RootView()
				.environmentObject(player)
				.environmentObject(downloads)
		}
		.modelContainer(modelContainer)

		MenuBarExtra("EchoPod", systemImage: "waveform") {
			VStack(spacing: 8) {
				GlobalPlayerBarView()
					.environmentObject(player)
					.environmentObject(downloads)
				Divider()
				NavigationStack {
					EchoComposerView()
						.environmentObject(player)
						.environmentObject(downloads)
				}
			}
		}
		.menuBarExtraStyle(.window)
		.modelContainer(modelContainer)
	}
}
