import SwiftUI

struct FlowLayout: View {
    var spacing: CGFloat
    var content: [AnyView]

    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        self.content = data.map { AnyView(content($0)) }
    }

    // Simplified version for the specific usage in ProjectStudioView if needed
    init(spacing: CGFloat = 8, @ViewBuilder content: () -> AnyView) {
        self.spacing = spacing
        self.content = [content()]
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            var width = CGFloat.zero
            var height = CGFloat.zero

            ForEach(0..<content.count, id: \.self) { index in
                content[index]
                    .alignmentGuide(.leading, computeValue: { d in
                        if (abs(width - d.width) > 300) { // Simple wrap logic
                            width = 0
                            height -= d.height + spacing
                        }
                        let result = width
                        if index == content.count - 1 {
                            width = 0 // last item
                        } else {
                            width -= d.width + spacing
                        }
                        return result
                    })
                    .alignmentGuide(.top, computeValue: { d in
                        let result = height
                        if index == content.count - 1 {
                            height = 0 // last item
                        }
                        return result
                    })
            }
        }
    }
}

// A better FlowLayout implementation for SwiftUI
struct FlexibleView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
  let data: Data
  let spacing: CGFloat
  let alignment: HorizontalAlignment
  let content: (Data.Element) -> Content
  @State private var availableWidth: CGFloat = 0

  var body: some View {
    ZStack(alignment: Alignment(horizontal: alignment, vertical: .center)) {
      Color.clear
        .frame(height: 1)
        .readSize { size in
          availableWidth = size.width
        }

      _FlexibleView(
        availableWidth: availableWidth,
        data: data,
        spacing: spacing,
        alignment: alignment,
        content: content
      )
    }
  }
}

struct _FlexibleView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
  let availableWidth: CGFloat
  let data: Data
  let spacing: CGFloat
  let alignment: HorizontalAlignment
  let content: (Data.Element) -> Content

  var body: some View {
    var width = CGFloat.zero
    var height = CGFloat.zero

    return ZStack(alignment: Alignment(horizontal: alignment, vertical: .center)) {
      ForEach(data, id: \.self) { element in
        content(element)
          .alignmentGuide(.leading, computeValue: { d in
            if (abs(width - d.width) > availableWidth) {
              width = 0
              height -= d.height + spacing
            }
            let result = width
            if element == data.last {
              width = 0
            } else {
              width -= d.width + spacing
            }
            return result
          })
          .alignmentGuide(.top, computeValue: { d in
            let result = height
            if element == data.last {
              height = 0
            }
            return result
          })
      }
    }
  }
}

extension View {
  func readSize(onChange: @escaping (CGSize) -> Void) -> some View {
    background(
      GeometryReader { geometry in
        Color.clear
          .preference(key: SizePreferenceKey.self, value: geometry.size)
      }
    )
    .onPreferenceChange(SizePreferenceKey.self) { size in
        onChange(size)
    }
  }
}

struct SizePreferenceKey: PreferenceKey {
  static var defaultValue: CGSize = .zero
  static func reduce(value: inout CGSize, nextValue: () -> CGSize) {}
}
