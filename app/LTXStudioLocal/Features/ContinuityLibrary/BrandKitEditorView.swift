import SwiftUI

struct BrandKitEditorView: View {
    @Binding var brandKit: BrandKit

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Text("Brand Kit Configuration")
                .font(.App.headline)

            Group {
                Text("Brand Assets")
                    .font(.App.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Logo Path")
                        .font(.App.caption)
                    TextField("Path to logo asset", text: Binding(
                        get: { brandKit.logoAssetPath ?? "" },
                        set: { brandKit.logoAssetPath = $0.isEmpty ? nil : $0 }
                    ))
                    .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Brand Colors (Hex)")
                        .font(.App.caption)
                    HStack {
                        ForEach(0..<brandKit.brandColors.count, id: \.self) { index in
                            TextField("#000000", text: $brandKit.brandColors[index])
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 100)
                        }
                        Button(action: { brandKit.brandColors.append("#FFFFFF") }) {
                            Image(systemName: "plus.circle.fill")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            Group {
                Text("Cards & Overlays")
                    .font(.App.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Intro Card Text")
                        .font(.App.caption)
                    TextField("Welcome message...", text: $brandKit.introCardText)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: Spacing.small) {
                    Text("Outro Card Text")
                        .font(.App.caption)
                    TextField("Closing message...", text: $brandKit.outroCardText)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Divider()

            Group {
                Text("Overlay Settings")
                    .font(.App.subheadline)
                    .foregroundColor(.secondary)

                Toggle("Enable Title Card", isOn: $brandKit.titleCardSettings.isEnabled)
                Toggle("Enable Lower Thirds", isOn: $brandKit.lowerThirdSettings.isEnabled)
                Toggle("Enable Watermark", isOn: $brandKit.watermarkSettings.isEnabled)
                Toggle("Enable Subtitles", isOn: $brandKit.subtitleStyleSettings.isEnabled)
            Group {
                Text("Watermark Position")
                    .font(.App.caption)
                Picker("", selection: $brandKit.watermarkSettings.position) {
                    ForEach(OverlayPosition.allCases, id: \.self) { position in
                        Text(position.rawValue.capitalized).tag(position)
                    }
                }
                .pickerStyle(.segmented)
            }
            }

            Divider()

            BrandPreviewPanel(brandKit: brandKit)
        }
    }
}

struct BrandPreviewPanel: View {
    let brandKit: BrandKit

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            Text("Preview")
                .font(.App.subheadline)

            ZStack {
                // Mock Video Background
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black)
                    .aspectRatio(16/9, contentMode: .fit)
                    .overlay(
                        Text("Video Preview")
                            .foregroundColor(.gray)
                    )

                // Watermark
                if brandKit.watermarkSettings.isEnabled {
                    overlayLayer(position: brandKit.watermarkSettings.position) {
                        Image(systemName: "seal.fill")
                            .foregroundColor(.white)
                            .opacity(brandKit.watermarkSettings.opacity)
                            .padding(8)
                    }
                }

                // Lower Third
                if brandKit.lowerThirdSettings.isEnabled {
                    overlayLayer(position: brandKit.lowerThirdSettings.position) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("SRE MARCEL")
                                .font(.system(size: 10, weight: .bold))
                            Text("LTX STUDIO LOCAL")
                                .font(.system(size: 8))
                        }
                        .padding(4)
                        .background(Color.blue.opacity(0.8))
                        .foregroundColor(.white)
                        .padding(8)
                    }
                }

                // Subtitles
                if brandKit.subtitleStyleSettings.isEnabled {
                    overlayLayer(position: .bottomCenter) {
                        Text("This is a preview of brand subtitles.")
                            .font(.system(size: 10))
                            .foregroundColor(.white)
                            .padding(4)
                            .background(Color.black.opacity(0.5))
                            .padding(.bottom, 20)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.App.border, lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func overlayLayer<Content: View>(position: OverlayPosition, @ViewBuilder content: () -> Content) -> some View {
        GeometryReader { geo in
            ZStack {
                content()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: mapAlignment(position))
        }
    }

    private func mapAlignment(_ position: OverlayPosition) -> Alignment {
        switch position {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        case .center: return .center
        case .topCenter: return .top
        case .bottomCenter: return .bottom
        }
    }
}
