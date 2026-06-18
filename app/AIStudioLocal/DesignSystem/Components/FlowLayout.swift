import SwiftUI

struct FlowLayout<Data: RandomAccessCollection, Content: View>: View {
    var spacing: CGFloat
    var data: Data
    var content: (Data.Element) -> Content

    init(
        _ data: Data,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        FlexibleView(
            data: data,
            spacing: spacing,
            alignment: .leading,
            content: content
        )
    }
}

// A better FlowLayout implementation for SwiftUI
struct FlexibleView<Data: RandomAccessCollection, Content: View>: View {
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

struct _FlexibleView<Data: RandomAccessCollection, Content: View>: View {
  let availableWidth: CGFloat
  let data: Data
  let spacing: CGFloat
  let alignment: HorizontalAlignment
  let content: (Data.Element) -> Content

  var body: some View {
    var width = CGFloat.zero
    var height = CGFloat.zero

    return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
      ForEach(Array(data.enumerated()), id: \.offset) { index, element in
        content(element)
          .fixedSize(horizontal: true, vertical: false) // Ensure content doesn't get squeezed by ZStack/AlignmentGuide
          .alignmentGuide(.leading, computeValue: { d in
            if (abs(width - d.width) > availableWidth) {
              width = 0
              height -= d.height + spacing
            }
            let result = width
            if index == data.count - 1 {
              width = 0
            } else {
              width -= d.width + spacing
            }
            return result
          })
          .alignmentGuide(.top, computeValue: { d in
            let result = height
            if index == data.count - 1 {
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
