import SwiftUI
import SwiftData

struct AddSubscriptionSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext

	@State private var urlText: String = ""
	@State private var isLoading = false
	@State private var errorText: String?

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("添加 RSS 订阅")
				.font(.title3)
				.bold()

			TextField("https://...", text: $urlText)
				.textFieldStyle(.roundedBorder)

			if let errorText {
				Text(errorText)
					.foregroundStyle(.red)
					.font(.caption)
			}

			HStack {
				Spacer()
				Button("取消") { dismiss() }
				Button(isLoading ? "订阅中..." : "订阅") {
					Task { @MainActor in await subscribe() }
				}
				.disabled(isLoading)
			}
		}
		.padding(16)
		.frame(width: 420)
	}

	@MainActor
	private func subscribe() async {
		errorText = nil
		let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard let url = URL(string: trimmed), url.scheme?.hasPrefix("http") == true else {
			errorText = "请输入合法的 http/https RSS 链接"
			return
		}

		isLoading = true
		defer { isLoading = false }

		let feed = PodcastFeed(url: url.absoluteString)
		modelContext.insert(feed)

		let service = RSSService(modelContext: modelContext)
		do {
			try await service.refresh(feed: feed)
			try? modelContext.save()
			dismiss()
		} catch {
			modelContext.delete(feed)
			errorText = "订阅失败：\(error.localizedDescription)"
		}
	}
}
