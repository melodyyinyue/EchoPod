import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
	case allEpisodes = "全部单集"
	case subscriptions = "我的订阅"
	case durationFilter = "时长筛选"
	case echoPodcasts = "我的回音"
	case coverDesign = "封面设计"
	case settings = "设置"

	var id: String { rawValue }

	var systemImage: String {
		switch self {
		case .allEpisodes: return "rectangle.stack"
		case .subscriptions: return "dot.radiowaves.left.and.right"
		case .durationFilter: return "clock.badge.checkmark"
		case .echoPodcasts: return "waveform"
		case .coverDesign: return "photo.artframe"
		case .settings: return "gearshape"
		}
	}
}


struct RootView: View {
    @State private var selection: SidebarItem? = .allEpisodes

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $selection) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
                }
            .listStyle(.sidebar)
            .navigationTitle("EchoPod")
        } detail: {
            switch selection {
            case .allEpisodes:
                AllEpisodesView()
            case .subscriptions:
                SubscriptionsView()
            case .durationFilter:
                DurationFilterView()
            case .echoPodcasts:
                EchoPodcastsView()
            case .coverDesign:
                CoverDesignView()
            case .settings:
                SettingsView()
            case .none:
                AllEpisodesView()
            }
        }
        .overlay(alignment: .bottom) {
            GlobalPlayerBarView()
                .frame(maxWidth: .infinity)
                .shadow(radius: 4)
        }
    }
}
