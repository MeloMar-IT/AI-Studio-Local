import SwiftUI

struct SystemReportView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.large) {
                Text("System Report")
                    .font(.App.title2)
                    .padding(.bottom, Spacing.small)

                // App Local Hardware
                ReportSection(title: "App Host Environment", icon: "laptopcomputer") {
                    ReportRow(label: "Model", value: appState.hardwareProfile.modelName)
                    ReportRow(label: "Memory", value: "\(appState.hardwareProfile.totalMemoryGB) GB")
                    ReportRow(label: "Apple Silicon", value: appState.hardwareProfile.isAppleSilicon ? "Yes" : "No", valueColor: appState.hardwareProfile.isAppleSilicon ? .green : .red)
                    ReportRow(label: "Performance Profile", value: appState.hardwareProfile.generationProfile.rawValue)
                    ReportRow(label: "Local Ready", value: appState.hardwareProfile.isLocalModeReady ? "✅ Ready" : "❌ Not Recommended", valueColor: appState.hardwareProfile.isLocalModeReady ? .green : .orange)
                }

                // Worker Environment
                if appState.isWorkerAvailable {
                    ReportSection(title: "AI Video Worker", icon: "cpu") {
                        ReportRow(label: "Status", value: appState.workerStatus == .running ? "CONNECTED" : "STOPPED", valueColor: appState.workerStatus == .running ? .green : .red)

                        if let wp = appState.workerHardwareProfile {
                            ReportRow(label: "Chip", value: wp.chip)
                            ReportRow(label: "Memory", value: "\(wp.totalMemoryGb) GB total (\(wp.freeMemoryGb) GB free)")
                            ReportRow(label: "Python Path", value: wp.pythonPath)
                            ReportRow(label: "Virtual Env", value: wp.venvPath)
                            ReportRow(label: "MLX Available", value: wp.mlxAvailable ? "✅ Yes" : "❌ No", valueColor: wp.mlxAvailable ? .green : .red)
                            ReportRow(label: "PyTorch Available", value: wp.pytorchAvailable ? "✅ Yes" : "❌ No", valueColor: wp.pytorchAvailable ? .green : .red)
                            ReportRow(label: "FFmpeg", value: wp.ffmpegAvailable ? "✅ Yes" : "❌ No", valueColor: wp.ffmpegAvailable ? .green : .red)

                            // Python Libraries
                            let missingCount = wp.librariesStatus.values.filter { !$0 }.count
                            ReportRow(label: "Python Libraries", value: missingCount == 0 ? "✅ All Installed" : "❌ \(missingCount) Missing", valueColor: missingCount == 0 ? .green : .red)

                            ReportRow(label: "Disk (Models)", value: String(format: "%.2f GB free", wp.freeDiskModelsGb))
                            ReportRow(label: "Disk (Outputs)", value: String(format: "%.2f GB free", wp.freeDiskOutputs_Gb))
                        } else {
                            HStack {
                                ReportRow(label: "Worker Profile", value: "Fetching...")
                                Spacer()
                                Button(action: {
                                    Task {
                                        await appState.refreshWorkerProfile()
                                    }
                                }) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.App.caption)
                                }
                                .buttonStyle(.plain)
                                .padding(.trailing, Spacing.medium)
                            }
                            .background(Color.App.surface)
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Worker not connected. Start the worker to see its environment report.")
                    }
                    .padding()
                    .background(Color.App.warning.opacity(0.1))
                    .cornerRadius(Spacing.cornerRadius)
                }

                // Recommendations / Messages
                if !appState.hardwareProfile.isLocalModeReady {
                    VStack(alignment: .leading, spacing: Spacing.small) {
                        Text("Recommendations")
                            .font(.App.headline)

                        if !appState.hardwareProfile.isAppleSilicon {
                            Text("• This application is optimized for Apple Silicon (M1/M2/M3/M4). Intel Macs may experience very slow generation or failures.")
                                .font(.App.callout)
                                .foregroundColor(.secondary)
                        }

                        if appState.hardwareProfile.totalMemoryGB < 16 {
                            Text("• At least 16GB of Unified Memory is recommended. You may encounter out-of-memory errors with standard models.")
                                .font(.App.callout)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.App.surface)
                    .cornerRadius(Spacing.cornerRadius)
                }
            }
            .padding(Spacing.large)
        }
        .background(Color.App.background)
    }
}

struct ReportSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.App.headline)
            }

            VStack(spacing: 1) {
                content
            }
            .background(Color.App.border)
            .cornerRadius(Spacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Spacing.cornerRadius)
                    .stroke(Color.App.border, lineWidth: 1)
            )
        }
    }
}

struct ReportRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(.medium)
        }
        .padding(.horizontal, Spacing.medium)
        .padding(.vertical, Spacing.small)
        .background(Color.App.surface)
    }
}
