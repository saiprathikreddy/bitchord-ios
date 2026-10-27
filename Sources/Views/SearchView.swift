import SwiftUI

/// Search tab: real-time search with song/artist/album filters.
@available(iOS 17.0, macOS 14.0, *)
struct SearchView: View {
    @EnvironmentObject private var audioManager: AudioPlaybackManager

    @State private var query = ""
    @State private var filter: SearchFilter = .songs
    @State private var results: SearchResult?
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar.
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search songs, artists, albums", text: $query)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task { await search() }
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            results = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.horizontal, 20)
                .padding(.top, 8)

                // Filter chips.
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(SearchFilter.allCases, id: \.self) { f in
                            Chip(title: f.rawValue.capitalized, isSelected: filter == f) {
                                filter = f
                                Task { await search() }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 10)

                // Results.
                Group {
                    if let results, !results.tracks.isEmpty {
                        List {
                            ForEach(results.tracks) { track in
                                TrackRowView(track: track) {
                                    Task {
                                        try? await audioManager.play(track: track)
                                    }
                                }
                                .listRowSeparator(.hidden)
                            }
                        }
                        .listStyle(.plain)
                    } else if isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ContentUnavailableView(
                            "Search",
                            systemImage: "magnifyingglass",
                            description: Text("Enter a search term to find music.")
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationTitle("Search")
        }
        .searchable(text: $query, prompt: "Search music")
        .onSubmit(of: .search) {
            Task { await search() }
        }
    }

    private func search() async {
        guard !query.isEmpty else { return }
        isSearching = true
        defer { isSearching = false }
        do {
            results = try await YouTubeMusicClient.shared.search(query: query, filter: filter)
        } catch {
            results = nil
        }
    }
}

/// Filter chip.
@available(iOS 17.0, macOS 14.0, *)
private struct Chip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.red : Color.white.opacity(0.12), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Search") {
    SearchView()
        .environmentObject(AudioPlaybackManager.shared)
}
