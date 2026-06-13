import SwiftUI
import AVKit

public struct PreviewPlayer: View {
    let videoURL: URL?
    let previewImageURL: URL?
    let errorMessage: String?
    let retryAction: (() -> Void)?

    @State private var player: AVPlayer?
    @State private var isMuted: Bool = true
    @State private var showControls: Bool = false
    @State private var videoError: String?

    public init(
        videoURL: URL? = nil,
        previewImageURL: URL? = nil,
        errorMessage: String? = nil,
        retryAction: (() -> Void)? = nil
    ) {
        self.videoURL = videoURL
        self.previewImageURL = previewImageURL
        self.errorMessage = errorMessage
        self.retryAction = retryAction
    }

    public var body: some View {
        ZStack {
            Color.black

            if let error = errorMessage ?? videoError {
                errorView(error)
            } else if let videoURL = videoURL {
                videoView(videoURL)
            } else if let previewImageURL = previewImageURL {
                previewImageView(previewImageURL)
            } else {
                emptyView
            }
        }
        .clipped()
        .cornerRadius(Spacing.cornerRadiusMedium)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    @ViewBuilder
    private func videoView(_ url: URL) -> some View {
        VideoPlayer(player: player)
            .onAppear {
                if player == nil {
                    setupPlayer()
                }
            }
            .overlay(
                VStack {
                    Spacer()
                    HStack {
                        Button {
                            isMuted.toggle()
                            player?.isMuted = isMuted
                        } label: {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundColor(.white)
                                .padding(Spacing.xSmall)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(Spacing.medium)

                        Spacer()
                    }
                }
            )
    }

    @ViewBuilder
    private func previewImageView(_ url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .controlSize(.small)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                VStack(spacing: Spacing.small) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 48))
                        .foregroundColor(Color.App.secondaryText)
                    Text("Preview image missing")
                        .font(.App.subheadline)
                        .foregroundColor(Color.App.secondaryText)
                }
            @unknown default:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: Spacing.medium) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(Color.App.error)

            Text(message)
                .font(.App.headline)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.large)

            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.App.body)
                        .padding(.horizontal, Spacing.medium)
                        .padding(.vertical, Spacing.xSmall)
                        .background(Color.App.accent)
                        .foregroundColor(.white)
                        .cornerRadius(Spacing.cornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: Spacing.small) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 64))
                .foregroundColor(Color.App.border)
            Text("No generation selected")
                .font(.App.subheadline)
                .foregroundColor(Color.App.secondaryText)
        }
    }

    private func setupPlayer() {
        guard let url = videoURL else { return }

        // Check if file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            videoError = "Video file missing at \(url.lastPathComponent)"
            return
        }

        let asset = AVAsset(url: url)

        // Check for supported tracks (codec support check)
        Task {
            let isPlayable = try? await asset.load(.isPlayable)
            let tracks = try? await asset.loadTracks(withMediaType: .video)

            await MainActor.run {
                if isPlayable == false || tracks?.isEmpty == true {
                    videoError = "Unsupported media format or corrupted file"
                } else {
                    let playerItem = AVPlayerItem(asset: asset)
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.isMuted = isMuted

                    // Loop playback
                    NotificationCenter.default.addObserver(
                        forName: .AVPlayerItemDidPlayToEndTime,
                        object: playerItem,
                        queue: .main
                    ) { _ in
                        newPlayer.seek(to: .zero)
                        newPlayer.play()
                    }

                    self.player = newPlayer
                    newPlayer.play()
                }
            }
        }
    }
}
