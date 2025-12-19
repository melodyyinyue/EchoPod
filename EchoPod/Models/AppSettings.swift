import Foundation
import SwiftData

@Model
final class AppSettings {
	@Attribute(.unique) var id: String

	var volcPodcastAppID: String?
	var volcPodcastAccessToken: String?
	var volcPodcastResourceID: String?

	var volcCoverAPIKey: String?
	var updatedAt: Date

	init(id: String = "singleton") {
		self.id = id
		self.volcPodcastResourceID = "volc.service_type.10050"
		self.updatedAt = Date()
	}
}
