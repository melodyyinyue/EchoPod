import Foundation
import SwiftData

enum RSSError: Error {
	case invalidResponse
	case parseFailed
}

@MainActor
final class RSSService {
	private let modelContext: ModelContext
	private let session: URLSession

	init(modelContext: ModelContext, session: URLSession = .shared) {
		self.modelContext = modelContext
		self.session = session
	}

	func refreshAllFeeds() async throws {
		let descriptor = FetchDescriptor<PodcastFeed>(sortBy: [SortDescriptor(\PodcastFeed.createdAt, order: .reverse)])
		let feeds = try modelContext.fetch(descriptor)
		for feed in feeds {
			try await refresh(feed: feed)
		}
		try? modelContext.save()
	}

	func refresh(feed: PodcastFeed) async throws {
		guard let url = URL(string: feed.url) else { return }
		let (data, response) = try await session.data(from: url)
		guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			throw RSSError.invalidResponse
		}

		let parser = RSSParser()
		guard let parsed = parser.parse(data: data) else {
			throw RSSError.parseFailed
		}

		feed.title = parsed.channelTitle ?? feed.title
		feed.author = parsed.channelAuthor ?? feed.author
		feed.imageURL = parsed.channelImageURL ?? feed.imageURL
		feed.lastFetchedAt = Date()

		for item in parsed.items {
			let guid = item.guid ?? item.audioURL
			let descriptor = FetchDescriptor<PodcastEpisode>(predicate: #Predicate { $0.guid == guid })
			let existed = try? modelContext.fetch(descriptor).first
			if let existed {
				existed.title = item.title ?? existed.title
				existed.summary = item.summary ?? existed.summary
				existed.publishedAt = item.publishedAt ?? existed.publishedAt
				existed.audioURL = item.audioURL
				existed.imageURL = item.imageURL ?? existed.imageURL
				existed.durationSeconds = item.durationSeconds ?? existed.durationSeconds
				existed.feed = feed
			} else {
				guard let title = item.title, !title.isEmpty else { continue }
				let ep = PodcastEpisode(guid: guid, title: title, audioURL: item.audioURL, publishedAt: item.publishedAt)
				ep.summary = item.summary
				ep.imageURL = item.imageURL
				ep.durationSeconds = item.durationSeconds
				ep.feed = feed
				modelContext.insert(ep)
			}
		}
	}
}
