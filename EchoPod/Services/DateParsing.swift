import Foundation

enum DateParsing {
	private static let rfc822Formatters: [DateFormatter] = {
		let locales = ["en_US_POSIX"]
		let formats = [
			"EEE, dd MMM yyyy HH:mm:ss Z",
			"dd MMM yyyy HH:mm:ss Z",
			"EEE, dd MMM yyyy HH:mm Z"
		]
		return locales.flatMap { localeID in
			formats.map { format in
				let df = DateFormatter()
				df.locale = Locale(identifier: localeID)
				df.dateFormat = format
				return df
			}
		}
	}()

	static func parseRfc822(_ s: String?) -> Date? {
		guard let s, !s.isEmpty else { return nil }
		for df in rfc822Formatters {
			if let d = df.date(from: s) { return d }
		}
		return nil
	}

	static func parseDurationSeconds(_ s: String?) -> Int? {
		guard let s, !s.isEmpty else { return nil }
		if let v = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) { return v }

		let parts = s.split(separator: ":").map { Int($0) }
		if parts.count == 2, let m = parts[0], let sec = parts[1] { return m * 60 + sec }
		if parts.count == 3, let h = parts[0], let m = parts[1], let sec = parts[2] { return h * 3600 + m * 60 + sec }
		return nil
	}
}
