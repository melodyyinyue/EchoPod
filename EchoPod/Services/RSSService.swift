import Foundation
import SwiftData
import CryptoKit

enum RSSError: Error {
	case invalidURL
	case networkError(underlying: Error)
	case timeout
	case httpStatus(Int, String?)
	case parseFailed(underlying: Error?)
}

extension RSSError: LocalizedError {
	var errorDescription: String? {
		switch self {
		case .invalidURL:
			return "RSS 链接不合法"
		case .networkError(let underlying):
			return "网络请求失败：\(underlying.localizedDescription)"
		case .timeout:
			return "网络请求超时，请检查网络连接"
		case .httpStatus(let code, let body):
			// 为常见 HTTP 状态码提供友好的错误提示
			let friendlyMessage: String
			switch code {
			case 404:
				friendlyMessage = "RSS 源不存在"
			case 403:
				friendlyMessage = "访问被拒绝，该 RSS 源可能需要授权"
			case 500...599:
				friendlyMessage = "RSS 服务器错误"
			case 301, 302, 307, 308:
				friendlyMessage = "RSS 源已重定向"
			default:
				friendlyMessage = "RSS 请求失败"
			}
			
			if let body, !body.isEmpty {
				return "\(friendlyMessage)（HTTP \(code)）：\(body)"
			}
			return "\(friendlyMessage)（HTTP \(code)）"
		case .parseFailed(let underlying):
			return "RSS 解析失败：\(underlying?.localizedDescription ?? "未知原因")"
		}
	}
}

@MainActor
final class RSSService {
	private let modelContext: ModelContext
	private let session: URLSession

	init(modelContext: ModelContext, session: URLSession? = nil) {
		self.modelContext = modelContext
		
		// 如果未提供 session，创建带超时配置的自定义 session
		if let session {
			self.session = session
		} else {
			let config = URLSessionConfiguration.default
			config.timeoutIntervalForRequest = 30.0  // 请求超时 30 秒
			config.timeoutIntervalForResource = 60.0  // 资源总超时 60 秒
			self.session = URLSession(configuration: config)
		}
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
		guard let url = URL(string: feed.url) else { throw RSSError.invalidURL }

		var req = URLRequest(url: url)
		req.setValue(
			"application/rss+xml, application/atom+xml, application/xml, text/xml;q=0.9, */*;q=0.8",
			forHTTPHeaderField: "Accept"
		)
		// 使用浏览器风格的 User-Agent 来避免被某些网站拦截
		req.setValue(
			"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15",
			forHTTPHeaderField: "User-Agent"
		)
		req.setValue("en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7", forHTTPHeaderField: "Accept-Language")

		// 捕获网络错误和超时错误
		let (data, response): (Data, URLResponse)
		do {
			(data, response) = try await session.data(for: req)
		} catch let error as URLError {
			// 处理超时错误
			if error.code == .timedOut {
				throw RSSError.timeout
			}
			// 其他网络错误
			throw RSSError.networkError(underlying: error)
		} catch {
			// 其他未知错误
			throw RSSError.networkError(underlying: error)
		}
		
		guard let http = response as? HTTPURLResponse else {
			throw RSSError.httpStatus(-1, "无效响应")
		}
		guard (200..<300).contains(http.statusCode) else {
			let snippet = String(data: data.prefix(512), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
			throw RSSError.httpStatus(http.statusCode, snippet)
		}

		let parser = RSSParser()
		let parsed: RSSParsedFeed
		do {
			parsed = try parser.parse(data: data)
		} catch {
			throw RSSError.parseFailed(underlying: error)
		}

		feed.title = parsed.channelTitle ?? feed.title
		feed.author = parsed.channelAuthor ?? feed.author
		feed.feedDescription = parsed.channelDescription ?? feed.feedDescription // 保存简介
		feed.imageURL = parsed.channelImageURL ?? feed.imageURL
		feed.lastFetchedAt = Date()

		// 尝试下载封面
		if let imgURLStr = feed.imageURL, let imgURL = URL(string: imgURLStr) {
			// 如果没有本地路径，或者本地文件不存在，则下载
			if feed.localCoverPath == nil || !FileManager.default.fileExists(atPath: feed.localCoverPath!) {
				if let localPath = await downloadCover(url: imgURL, feedURL: feed.url) {
					feed.localCoverPath = localPath
				}
			}
		}

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

	private func downloadCover(url: URL, feedURL: String) async -> String? {
		do {
			let (data, _) = try await session.data(from: url)
			let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
			let dir = appSupport.appendingPathComponent("EchoPod/RSSCovers", isDirectory: true)
			try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
			
			let name = sha256Hex(feedURL).prefix(16)
			// 保留原始扩展名或默认 jpg，简单起见统一用 jpg 或者根据 response mime type。
			// 这里简单用 jpg
			let fileURL = dir.appendingPathComponent("\(name).jpg")
			
			try data.write(to: fileURL)
			return fileURL.path
		} catch {
			print("Download cover failed: \(error)")
			return nil
		}
	}

	private func sha256Hex(_ s: String) -> String {
		let digest = SHA256.hash(data: Data(s.utf8))
		return digest.map { String(format: "%02x", $0) }.joined()
	}
}
