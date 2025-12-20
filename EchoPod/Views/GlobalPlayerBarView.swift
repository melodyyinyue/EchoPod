import SwiftUI
import SwiftData

struct GlobalPlayerBarView: View {
    @EnvironmentObject private var player: PlayerController
    @Environment(\.modelContext) private var modelContext

    @State private var currentEpisode: PodcastEpisode?
    @State private var currentEchoPodcast: EchoPodcast?

    private var currentTimeBinding: Binding<Double> {
        Binding(
            get: { player.currentTime },
            set: { newValue in player.seek(to: newValue) }
        )
    }
    
    private var displayTitle: String {
        if let ep = currentEpisode {
            return ep.title
        } else if let echo = currentEchoPodcast {
            return echo.title
        }
        return "未播放"
    }
    
    private var displaySubtitle: String {
        if let ep = currentEpisode {
            return ep.feed?.title ?? ""
        } else if currentEchoPodcast != nil {
            return "EchoPod 回音播客"
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                // 封面图
                coverView
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(displaySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    if player.isPlaying { player.pause() } else { player.togglePlayPause() }
                } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(TactileButtonStyle())
            }

            if player.duration > 0 {
                HStack(spacing: 8) {
                    Text(formatTime(player.currentTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: currentTimeBinding, in: 0...(max(1, player.duration)))
                        .tint(AppTheme.primary)
                    Text(formatTime(player.duration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thickMaterial)
        .onAppear { refreshContent() }
        .onChange(of: player.currentURL) { _, _ in refreshContent() }
    }
    
    @ViewBuilder
    private var coverView: some View {
        if let ep = currentEpisode, let cover = coverURL(for: ep) {
            AsyncImage(url: cover) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    defaultCover
                }
            }
        } else if let echo = currentEchoPodcast, let cover = echo.coverURL, let url = URL(string: cover) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    echoCover
                }
            }
        } else if currentEchoPodcast != nil {
            echoCover
        } else {
            defaultCover
        }
    }
    
    private var defaultCover: some View {
        LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    
    private var echoCover: some View {
        ZStack {
            AppTheme.primaryGradient
            Image(systemName: "mic.fill")
                .foregroundStyle(.white)
                .font(.caption)
        }
    }

    private func refreshContent() {
        currentEpisode = nil
        currentEchoPodcast = nil
        
        guard let url = player.currentURL else { return }
        let audio = url.absoluteString
        let path = url.isFileURL ? url.path : nil
        
        // 先尝试查找 PodcastEpisode
        if let p = path {
            let predicate: Predicate<PodcastEpisode> = #Predicate { ep in ep.localFilePath == p }
            var fd = FetchDescriptor<PodcastEpisode>(predicate: predicate)
            fd.fetchLimit = 1
            if let found = try? modelContext.fetch(fd).first {
                currentEpisode = found
                return
            }
        }
        
        do {
            let predicate: Predicate<PodcastEpisode> = #Predicate { ep in ep.audioURL == audio }
            var fd = FetchDescriptor<PodcastEpisode>(predicate: predicate)
            fd.fetchLimit = 1
            if let found = try modelContext.fetch(fd).first {
                currentEpisode = found
                return
            }
        } catch {}
        
        // 尝试查找 EchoPodcast
        if let p = path {
            let predicate: Predicate<EchoPodcast> = #Predicate { ep in ep.localFilePath == p }
            var fd = FetchDescriptor<EchoPodcast>(predicate: predicate)
            fd.fetchLimit = 1
            if let found = try? modelContext.fetch(fd).first {
                currentEchoPodcast = found
                return
            }
        }
        
        do {
            let predicate: Predicate<EchoPodcast> = #Predicate { ep in ep.audioURL == audio }
            var fd = FetchDescriptor<EchoPodcast>(predicate: predicate)
            fd.fetchLimit = 1
            if let found = try modelContext.fetch(fd).first {
                currentEchoPodcast = found
                return
            }
        } catch {}
    }

    private func coverURL(for episode: PodcastEpisode) -> URL? {
        if let s = episode.imageURL, let u = URL(string: s) { return u }
        if let s = episode.feed?.imageURL, let u = URL(string: s) { return u }
        return nil
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}
