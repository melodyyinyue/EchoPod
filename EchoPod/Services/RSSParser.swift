import Foundation

struct RSSParsedFeed {
	var channelTitle: String?
	var channelDescription: String?
	var channelAuthor: String?
	var channelImageURL: String?
	var items: [RSSItem]
}

struct RSSItem {
	var guid: String?
	var title: String?
	var summary: String?
	var publishedAt: Date?
	var audioURL: String
	var imageURL: String?
	var durationSeconds: Int?
}

enum RSSParserError: Error {
	case parseFailed(underlying: Error?)
}

final class RSSParser: NSObject {
	private var currentElement: String = ""
	private var currentText: String = ""

	private var inItem = false
	private var insideChannelImage = false
	private var parsedFeed = RSSParsedFeed(items: [])
	private var currentItem: TempItem?

	private struct TempItem {
		var guid: String?
		var title: String?
		var summary: String?
		var pubDate: String?
		var audioURL: String?
		var imageURL: String?
		var duration: String?
	}

	func parse(data: Data) throws -> RSSParsedFeed {
		parsedFeed = RSSParsedFeed(items: [])
		currentItem = nil
		inItem = false
		insideChannelImage = false
		currentElement = ""
		currentText = ""

		let xml = XMLParser(data: data)
		xml.delegate = self
		let ok = xml.parse()
		if !ok {
			throw RSSParserError.parseFailed(underlying: xml.parserError)
		}
		return parsedFeed
	}
}

extension RSSParser: XMLParserDelegate {
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
		currentElement = (qName ?? elementName)
		currentText = ""

		let elementLower = elementName.lowercased()
		let qualifiedLower = (qName ?? elementName).lowercased()

		if elementLower == "item" || elementLower == "entry" {
			inItem = true
			currentItem = TempItem()
			return
		}

		if !inItem {
			if elementLower == "image" {
				insideChannelImage = true
			}
			if qualifiedLower == "itunes:image", let href = attributeDict["href"], !href.isEmpty {
				parsedFeed.channelImageURL = href
			}
			return
		}

		// in item
		if elementLower == "enclosure", let urlString = attributeDict["url"], let url = URL(string: urlString) {
			currentItem?.audioURL = url.absoluteString
		}

		if elementLower == "link" {
			let rel = attributeDict["rel"]?.lowercased()
			let type = attributeDict["type"]?.lowercased()
			if rel == "enclosure", let href = attributeDict["href"], let url = URL(string: href) {
				currentItem?.audioURL = url.absoluteString
			} else if let type, type.hasPrefix("audio"), let href = attributeDict["href"], let url = URL(string: href) {
				currentItem?.audioURL = url.absoluteString
			}
		}

		if qualifiedLower == "media:content", let urlString = attributeDict["url"], let url = URL(string: urlString) {
			currentItem?.audioURL = url.absoluteString
		}

		if qualifiedLower.hasSuffix(":image"), let href = attributeDict["href"], !href.isEmpty {
			currentItem?.imageURL = href
		}
		if qualifiedLower == "itunes:image", let href = attributeDict["href"], !href.isEmpty {
			currentItem?.imageURL = href
		}
	}

	func parser(_ parser: XMLParser, foundCharacters string: String) {
		currentText += string
	}

	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		let element = (qName ?? elementName).lowercased()
		let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
		defer {
			currentElement = ""
			currentText = ""
		}

		if inItem {
			switch element {
			case "guid", "id":
				if !trimmed.isEmpty { currentItem?.guid = trimmed }
			case "title":
				if !trimmed.isEmpty { currentItem?.title = trimmed }
			case "description", "summary", "content", "content:encoded":
				if !(currentItem?.summary?.isEmpty == false), !trimmed.isEmpty {
					currentItem?.summary = trimmed
				}
			case "pubdate", "published", "updated":
				if !trimmed.isEmpty { currentItem?.pubDate = trimmed }
			case "itunes:duration":
				if !trimmed.isEmpty { currentItem?.duration = trimmed }
			default:
				break
			}

			let elementLower = elementName.lowercased()
			if elementLower == "item" || elementLower == "entry" {
				inItem = false
				if let item = currentItem, let audio = item.audioURL, !audio.isEmpty {
					let date = DateParsing.parseRSSDate(item.pubDate)
					let durationSeconds = DateParsing.parseDurationSeconds(item.duration)
					parsedFeed.items.append(
						RSSItem(
							guid: item.guid,
							title: item.title,
							summary: item.summary,
							publishedAt: date,
							audioURL: audio,
							imageURL: item.imageURL,
							durationSeconds: durationSeconds
						)
					)
				}
				currentItem = nil
			}
			return
		}

		switch element {
		case "title":
			if parsedFeed.channelTitle == nil, !trimmed.isEmpty { parsedFeed.channelTitle = trimmed }
		case "description", "itunes:summary":
			if parsedFeed.channelDescription == nil, !trimmed.isEmpty { parsedFeed.channelDescription = trimmed }
		case "itunes:author", "author", "dc:creator":
			if parsedFeed.channelAuthor == nil, !trimmed.isEmpty { parsedFeed.channelAuthor = trimmed }
		case "url":
			if insideChannelImage, parsedFeed.channelImageURL == nil, !trimmed.isEmpty { parsedFeed.channelImageURL = trimmed }
		default:
			break
		}

		if elementName.lowercased() == "image" {
			insideChannelImage = false
		}
	}
}
