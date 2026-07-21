import SwiftUI
import AVKit
import AppKit

// Lightweight AVPlayerLayer-backed view, used instead of AVKit's SwiftUI
// `VideoPlayer` below. `VideoPlayer` wraps `AVKit.AVPlayerView`, a heavy
// ObjC-runtime control with its own transport UI/PiP/etc., and under an app
// launched via `swift run` (no proper .app bundle / Info.plist -- see
// scripts/run-app.sh) it reliably crashed with:
//   "failed to demangle superclass of VideoPlayerView from mangled name
//   'So12AVPlayerViewC': unknown error"
// followed immediately by SIGABRT -- visible in logs/run.log right after
// every single generation completed and the preview tried to play the new
// video. AVPlayerLayer is a plain CALayer primitive with no AVKit UI chrome
// and doesn't go through that code path. We already draw our own mute-button
// overlay below, so no functionality is lost by dropping AVKit's built-in
// controls.
private final class PlayerLayerView: NSView {
    let playerLayer = AVPlayerLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        playerLayer.videoGravity = .resizeAspect
        layer = playerLayer
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct PlayerLayerRepresentable: NSViewRepresentable {
    let player: AVPlayer?

    func makeNSView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.player = player
        return view
    }

    func updateNSView(_ nsView: PlayerLayerView, context: Context) {
        if nsView.playerLayer.player !== player {
            nsView.playerLayer.player = player
        }
    }
}

public struct PreviewPlayer: View {
    let videoURL: URL?
    let previewImageURL: URL?
    let errorMessage: String?
    let retryAction: (() -> Void)?

    @State private var player: AVPlayer?
    @State private var isMuted: Bool = true
    @State private var showControls: Bool = false
    @State private var videoError: String?
    // Tracks the URL setupPlayer() last built a player for, and the
    // NotificationCenter loop-playback observer for that player's item, so we
    // can tear the old one down instead of leaking it (the old code
    // registered a new block-based observer on every setupPlayer() call and
    // never removed any of them).
    @State private var loadedURL: URL?
    @State private var endObserver: NSObjectProtocol?

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
        .onChange(of: videoURL) { _, _ in
            // The view identity doesn't change when a scene's videoURL is
            // swapped for a different completed job's output (still the same
            // PreviewPlayer in the tree), so .onAppear alone won't refire and
            // the old code relied on a second .onAppear nested inside
            // videoView(_:) to catch this -- which just raced setupPlayer()
            // against the outer one on first appearance instead. onChange is
            // the correct place to react to the URL actually changing.
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
    }

    @ViewBuilder
    private func videoView(_ url: URL) -> some View {
        PlayerLayerRepresentable(player: player)
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
        guard let url = videoURL else {
            teardownPlayer()
            return
        }

        // Already loaded for this exact URL -- don't tear down and rebuild a
        // perfectly good player (this also protects against onAppear and
        // onChange both firing for the same URL on first appearance).
        if url == loadedURL, player != nil {
            return
        }

        // Check if file exists
        if !FileManager.default.fileExists(atPath: url.path) {
            videoError = "Video file missing at \(url.lastPathComponent)"
            return
        }

        videoError = nil
        teardownPlayer()
        loadedURL = url

        let asset = AVAsset(url: url)

        // Check for supported tracks (codec support check)
        Task {
            let isPlayable = try? await asset.load(.isPlayable)
            let tracks = try? await asset.loadTracks(withMediaType: .video)

            await MainActor.run {
                // The URL may have changed again while we were awaiting.
                guard url == loadedURL else { return }

                if isPlayable == false || tracks?.isEmpty == true {
                    videoError = "Unsupported media format or corrupted file"
                } else {
                    let playerItem = AVPlayerItem(asset: asset)
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.isMuted = isMuted

                    // Loop playback. Stored so teardownPlayer() can remove it --
                    // the previous version registered a new observer on every
                    // setupPlayer() call and never removed any of them.
                    endObserver = NotificationCenter.default.addObserver(
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

    private func teardownPlayer() {
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
        player?.pause()
        player = nil
        loadedURL = nil
    }
}
