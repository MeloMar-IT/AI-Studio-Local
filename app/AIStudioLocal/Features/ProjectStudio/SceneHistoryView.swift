import SwiftUI

struct SceneHistoryView: View {
    let generations: [SceneGeneration]
    let onUse: (SceneGeneration) -> Void
    let onViewPrompt: (SceneGeneration) -> Void
    let onDelete: (SceneGeneration) -> Void
    let onRegenerate: (SceneGeneration) -> Void

    let columns = [
        GridItem(.adaptive(minimum: 140))
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            if generations.isEmpty {
                VStack(spacing: Spacing.medium) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 32))
                        .foregroundColor(Color.App.border)
                    Text("No generation history yet.")
                        .font(.App.subheadline)
                        .foregroundColor(Color.App.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.large)
            } else {
                LazyVGrid(columns: columns, spacing: Spacing.medium) {
                    ForEach(generations.sorted(by: { $0.createdAt > $1.createdAt })) { generation in
                        GenerationVersionCard(
                            generation: generation,
                            onUse: { onUse(generation) },
                            onViewPrompt: { onViewPrompt(generation) },
                            onDelete: { onDelete(generation) },
                            onRegenerate: { onRegenerate(generation) }
                        )
                    }
                }
            }
        }
    }
}
