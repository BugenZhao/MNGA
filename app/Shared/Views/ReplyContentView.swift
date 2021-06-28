//
//  ReplyContentView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import RemoteImage

struct ReplyImageView: View {
  let url: URL

//  @StateObject var service = DefaultRemoteImageServiceFactory.makeDefaultRemoteImageService()

  var body: some View {

    RemoteImage(
      type: .url(url),
//        service: service,
      errorView: { e in Text("\(e.localizedDescription): \(url)") },
      imageView: { image in
        image.resizable().aspectRatio(contentMode: .fit)
      },
      loadingView: { HStack {
        Spacer()
        ProgressView()
        Spacer()
      } }
    )
  }
}

class ViewsCombiner {
  class PropertyGuard<P> {
    let combiner: ViewsCombiner
    let property: ReferenceWritableKeyPath<ViewsCombiner, [P]>

    init(
      _ combiner: ViewsCombiner,
      _ property: ReferenceWritableKeyPath<ViewsCombiner, [P]>
    ) {
      self.combiner = combiner
      self.property = property
    }

    deinit {
      let _ = combiner[keyPath: property].popLast()
    }
  }

  var views = [AnyView]()
  var textBuffer: Text? = nil

  var colors = [Color.primary]

  func append<V: View>(_ view: V) {
    if view is Text {
      if textBuffer == nil {
        textBuffer = view as? Text
      } else {
        textBuffer = textBuffer! + (view as! Text)
      }
    } else {
      if let textBuffer = textBuffer {
        views.append(AnyView(textBuffer))
        self.textBuffer = nil
      }
      views.append(AnyView(view))
    }
  }

  func appendBreakLine() {
    if let textBuffer = textBuffer {
      views.append(AnyView(textBuffer))
      self.textBuffer = nil
    } else {
      views.append(AnyView(Text("")))
    }
  }

  func build() -> [AnyView] {
    if let textBuffer = textBuffer {
      views.append(AnyView(textBuffer))
      self.textBuffer = nil
    }
    return views
  }
}

struct ReplyContentView: View {
  let spans: [Span]

  var body: some View {
    let views = buildViews()

    VStack(alignment: .leading) {
      ForEach(views.indices, id: \.self) { index in
        views[index]
      }
    }
  }

  func buildViews() -> [AnyView] {
    let combiner = ViewsCombiner()
    var fonts = [Font.callout]
    var colors = [Color.primary]

    func visitSpans(_ spans: [Span]) {
      spans.forEach(visit)
    }

    func visit(_ span: Span) {
      guard let value = span.value else { return }

      var text: Text? = nil

      switch value {
      case .breakLine(_):
        combiner.appendBreakLine()
      case .plain(let plain):
        text = Text(plain.text)
      case .sticker(let sticker):
        text = Text(sticker.name)
      case .tagged(let tagged):
        switch tagged.tag {
        case "img":
          visitImage(tagged)
        case "quote":
          visitQuote(tagged)
        case "b":
          visitBold(tagged)
        case "uid":
          visitUID(tagged)
        case "pid":
          visitPID(tagged)
        default:
          visitDefault(tagged)
        }
      }

      if let text = text {
        combiner.append(
          text
            .font(fonts.last)
            .foregroundColor(colors.last)
        )
      }
    }

    func visitImage(_ tagged: Span.Tagged) {
      guard let value = tagged.spans.first?.value else { return }
      guard case .plain(let plain) = value else { return }
      var urlText = plain.text
      if !urlText.contains("http") {
        urlText = "https://img.nga.178.com/attachments/" + urlText
      }
      guard let url = URL(string: urlText) else { return }

      let image = ReplyImageView(url: url)

      combiner.append(image)
    }

    func visitQuote(_ tagged: Span.Tagged) {
      fonts.append(.subheadline)
      colors.append(.secondary)

      visitSpans(tagged.spans)

      let _ = fonts.popLast()
      let _ = colors.popLast()
    }

    func visitBold(_ tagged: Span.Tagged) {
      fonts.append(fonts.last!.bold())

      visitSpans(tagged.spans)

      let _ = fonts.popLast()
    }

    func visitUID(_ tagged: Span.Tagged) {
      colors.append(.accentColor)

      visitSpans(tagged.spans)

      let _ = colors.popLast()
    }

    func visitPID(_ tagged: Span.Tagged) {
      if let pid = tagged.attributes.first {
        combiner.append(
          Text(" #\(pid) ")
        )
      }
    }

    func visitDefault(_ tagged: Span.Tagged) {
      visitSpans(tagged.spans)
    }

    spans.forEach(visit)

    return combiner.build()
  }
}
