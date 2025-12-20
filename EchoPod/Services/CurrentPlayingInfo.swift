import Foundation
import Combine

/// 共享的当前播放信息（用于流式播放时同步状态栏显示）
@MainActor
final class CurrentPlayingInfo: ObservableObject {
	static let shared = CurrentPlayingInfo()
	
	@Published var echoPodcastTitle: String?
	@Published var echoPodcastCoverURL: URL?
	@Published var isStreamingEchoPodcast: Bool = false
    @Published var currentEchoPodcast: EchoPodcast?
	
	private init() {}
	
	func setEchoPodcast(title: String, coverURL: URL?) {
		echoPodcastTitle = title
		echoPodcastCoverURL = coverURL
		isStreamingEchoPodcast = true
	}
	
	func clearEchoPodcast() {
		echoPodcastTitle = nil
		echoPodcastCoverURL = nil
		isStreamingEchoPodcast = false
	}
}
