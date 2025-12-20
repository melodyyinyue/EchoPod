import Foundation
import SwiftData

@Model
final class PodcastFeed {
	@Attribute(.unique) var url: String
	var title: String?
	var author: String?
	var feedDescription: String?
	var imageURL: String?
	var localCoverPath: String?
	var lastFetchedAt: Date?
	var createdAt: Date

	@Relationship(deleteRule: .cascade)
	var episodes: [PodcastEpisode] = []

	init(url: String) {
		self.url = url
		self.createdAt = Date()
	}
}
