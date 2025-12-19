import Foundation
import SwiftData

@Model
final class PodcastEpisode {
	@Attribute(.unique) var guid: String
	var title: String
	var summary: String?
	var publishedAt: Date?
	var audioURL: String
	var imageURL: String?
	var durationSeconds: Int?

	var localFilePath: String?
	var downloadedAt: Date?

	var isPlayed: Bool
	var createdAt: Date

	var feed: PodcastFeed?

	init(
		guid: String,
		title: String,
		audioURL: String,
		publishedAt: Date? = nil
	) {
		self.guid = guid
		self.title = title
		self.audioURL = audioURL
		self.publishedAt = publishedAt
		self.isPlayed = false
		self.createdAt = Date()
	}
}
