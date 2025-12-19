import Foundation

struct RSSParsedFeed {
	var channelTitle: String?
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

final class RSSParser: NSObject {
	private var currentElement: String = ""
	private var currentText: String = ""

	private var inItem = false
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

	func parse(data: Data) -> RSSParsedFeed? {
		parsedFeed = RSSParsedFeed(items: [])
		currentItem = nil
		inItem = false
		currentElement = ""
		currentText = ""

		let xml = XMLParser(data: data)
		xml.delegate = self
		return xml.parse() ? parsedFeed : nil
	}
}

extension RSSParser: XMLParserDelegate {
	func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
		currentElement = elementName
		currentText = ""

		if elementName == "item" {
			inItem = true
			currentItem = TempItem()
			return
		}

		if inItem {
			if elementName == "enclosure", let url = attributeDict["url"] {
				currentItem?.audioURL = url
			}
			if (qName == "itunes:image" || elementName == "itunes:image" || elementName == "image"), let href = attributeDict["href"] {
				currentItem?.imageURL = href
			}
		} else {
			if (qName == "itunes:image" || elementName == "itunes:image"), let href = attributeDict["href"] {
				parsedFeed.channelImageURL = href
			}
		}
	}

	func parser(_ parser: XMLParser, foundCharacters string: String) {
		currentText += string
	}

	func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
		let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
		defer {
			currentElement = ""
			currentText = ""
		}

		if inItem {
			switch elementName {
			case "guid":
				if !text.isEmpty { currentItem?.guid = text }
			case "title":
				if !text.isEmpty { currentItem?.title = text }
			case "description", "summary", "content:encoded":
				if !text.isEmpty { currentItem?.summary = text }
			case "pubDate":
				if !text.isEmpty { currentItem?.pubDate = text }
			case "itunes:duration":
				if !text.isEmpty { currentItem?.duration = text }
			case "item":
				inItem = false
				if let item = currentItem, let audio = item.audioURL {
					let date = DateParsing.parseRfc822(item.pubDate)
					let durationSeconds = DateParsing.parseDurationSeconds(item.duration)
					parsedFeed.items.append(RSSItem(guid: item.guid, title: item.title, summary: item.summary, publishedAt: date, audioURL: audio, imageURL: item.imageURL, durationSeconds: durationSeconds))
				}
				currentItem = nil
			default:
				break
			}
			return
		}

		switch elementName {
		case "title":
			if parsedFeed.channelTitle == nil, !text.isEmpty { parsedFeed.channelTitle = text }
		case "itunes:author":
			if parsedFeed.channelAuthor == nil, !text.isEmpty { parsedFeed.channelAuthor = text }
		default:
			break
		}
	}
}
