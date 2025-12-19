import Foundation

struct VolcEchoClient {
	let podcastAPIKey: String
	let coverAPIKey: String?
	let session: URLSession

	init(podcastAPIKey: String, coverAPIKey: String? = nil, session: URLSession = .shared) {
		self.podcastAPIKey = podcastAPIKey
		self.coverAPIKey = coverAPIKey
		self.session = session
	}

	// NOTE: 这里按文档摘要实现（可能需要你按实际控制台/账号的鉴权方式微调）。
	func generatePodcast(question: String, voiceID: String = "xiaoyou", speed: Double = 1.0) async throws -> (jobID: String, audioURL: String) {
		let submitURL = URL(string: "https://vod.volcengineapi.com/v1/video/audio/podcast")!

		struct SubmitBody: Encodable {
			let tts_text: String
			let voice_id: String
			let speed: Double
		}

		struct SubmitResponse: Decodable {
			struct DataField: Decodable { let job_id: String? }
			let code: Int?
			let message: String?
			let data: DataField?
		}

		var req = URLRequest(url: submitURL)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.setValue("Bearer \(podcastAPIKey)", forHTTPHeaderField: "Authorization")
		req.httpBody = try JSONEncoder().encode(SubmitBody(tts_text: question, voice_id: voiceID, speed: speed))

		let (data, resp) = try await session.data(for: req)
		guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			throw URLError(.badServerResponse)
		}
		let submit = try JSONDecoder().decode(SubmitResponse.self, from: data)
		let jobID = submit.data?.job_id ?? ""
		if jobID.isEmpty {
			throw NSError(domain: "VolcEchoClient", code: submit.code ?? -1, userInfo: [NSLocalizedDescriptionKey: submit.message ?? "提交生成任务失败"])
		}

		let statusBase = URL(string: "https://vod.volcengineapi.com/v1/video/audio/podcast/status")!
		var comps = URLComponents(url: statusBase, resolvingAgainstBaseURL: false)!
		comps.queryItems = [URLQueryItem(name: "job_id", value: jobID)]
		let statusURL = comps.url!

		struct StatusResponse: Decodable {
			struct DataField: Decodable {
				let status: String?
				let progress: Int?
				let audio_url: String?
			}
			let code: Int?
			let message: String?
			let data: DataField?
		}

		for _ in 0..<40 { // ~40 * 3s = 2min
			var sreq = URLRequest(url: statusURL)
			sreq.httpMethod = "GET"
			sreq.setValue("Bearer \(podcastAPIKey)", forHTTPHeaderField: "Authorization")

			let (sdata, sresp) = try await session.data(for: sreq)
			guard let shttp = sresp as? HTTPURLResponse, (200..<300).contains(shttp.statusCode) else {
				throw URLError(.badServerResponse)
			}
			let status = try JSONDecoder().decode(StatusResponse.self, from: sdata)
			let st = (status.data?.status ?? "").uppercased()
			if st == "SUCCESS" {
				let audio = status.data?.audio_url ?? ""
				if audio.isEmpty {
					throw NSError(domain: "VolcEchoClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "生成成功但未返回 audio_url"])
				}
				return (jobID, audio)
			}
			if st == "FAIL" {
				throw NSError(domain: "VolcEchoClient", code: status.code ?? -3, userInfo: [NSLocalizedDescriptionKey: status.message ?? "生成失败"])
			}

			try await Task.sleep(nanoseconds: 3_000_000_000)
		}

		throw NSError(domain: "VolcEchoClient", code: -4, userInfo: [NSLocalizedDescriptionKey: "生成超时，请稍后重试"])
	}

	func generateCover(prompt: String, width: Int = 768, height: Int = 768) async throws -> String? {
		guard let coverAPIKey, !coverAPIKey.isEmpty else { return nil }
		let url = URL(string: "https://model-inference.volcengineapi.com/v1/image/cover:generate")!

		struct Body: Encodable {
			let model_id: String
			let prompt: String
			let width: Int
			let height: Int
			let num_images: Int
		}

		struct Resp: Decodable {
			struct Result: Decodable { let image_url: String? }
			let results: [Result]?
			let request_id: String?
		}

		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.setValue("Bearer \(coverAPIKey)", forHTTPHeaderField: "Authorization")
		req.httpBody = try JSONEncoder().encode(Body(model_id: "seedream-4.5-cover", prompt: prompt, width: width, height: height, num_images: 1))

		let (data, resp) = try await session.data(for: req)
		guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			throw URLError(.badServerResponse)
		}
		let decoded = try JSONDecoder().decode(Resp.self, from: data)
		return decoded.results?.first?.image_url
	}
}
