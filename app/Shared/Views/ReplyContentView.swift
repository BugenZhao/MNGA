//
//  ReplyContentView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ReplyImageView: View {
  let url: URL

  var body: some View {
    WebImage(url: url)
      .resizable()
      .indicator(.activity)
      .scaledToFit()
  }
}

fileprivate class ViewsCombiner {
  var target: ReferenceWritableKeyPath<ViewsCombiner, [AnyView]> = \.views

  var views = [AnyView]()
  var textBuffer: Text? = nil

  var colors = [Color.primary]
  var fonts = [Font.callout]

  var quoteViews = [AnyView]()
  var pid: String? = nil

  func append<V: View>(_ view: V) {
    if view is Text {
      let view = (view as! Text)
        .font(fonts.last)
        .foregroundColor(colors.last)

      if textBuffer == nil {
        textBuffer = view
      } else {
        textBuffer = textBuffer! + view
      }
    } else {
      if let textBuffer = textBuffer {
        self[keyPath: target].append(AnyView(textBuffer))
        self.textBuffer = nil
      }
      self[keyPath: target].append(AnyView(view))
    }
  }

  func appendBreakLine() {
    if let textBuffer = textBuffer {
      self[keyPath: target].append(AnyView(textBuffer))
      self.textBuffer = nil
    } else {
      self[keyPath: target].append(AnyView(Text("")))
    }
  }

  func appendPID(_ pid: String) {
    guard target == \.quoteViews else { return }
    self.pid = pid
    self.append(Text("Reply"))
    self.append(Text(" #\(pid) "))
  }

  func build() -> [AnyView] {
    if let textBuffer = textBuffer {
      views.append(AnyView(textBuffer))
      self.textBuffer = nil
    }
    return views
  }

  func withColor(_ color: Color?, _ action: @escaping () -> Void) {
    if let color = color {
      colors.append(color)
      action()
      let _ = colors.popLast()
    } else {
      action()
    }
  }

  func withFont(_ font: Font?, _ action: @escaping () -> Void) {
    if let font = font {
      fonts.append(font)
      action()
      let _ = fonts.popLast()
    } else {
      action()
    }
  }

//  func withQuote(_ action: @escaping () -> Void) {
//    let oldTarget = target
//    target = \.quoteViews
//
//    self.withFont(.subheadline) {
//      self.withColor(.secondary) {
//        action()
//      }
//    }
//
//    if let pid = self.pid {
//
//    }
//
//    target = oldTarget
//    pid = nil
//  }

  var lastFont: Font? {
    fonts.last
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
        text = Text("[🐶\(sticker.name)]").foregroundColor(.secondary)
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
        combiner.append(text)
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
      combiner.withFont(.subheadline) {
        combiner.withColor(.secondary) {
          visitSpans(tagged.spans)
        }
      }
    }

    func visitBold(_ tagged: Span.Tagged) {
      combiner.withFont(combiner.lastFont?.bold()) {
        if tagged.spans.first?.plain.text.starts(with: "Reply to") == true {
          visitQuote(Span.Tagged.with { $0.spans = Array(tagged.spans.dropFirst()) })
        } else {
          visitSpans(tagged.spans)
        }
      }
    }

    func visitUID(_ tagged: Span.Tagged) {
      combiner.withColor(.accentColor) {
        visitSpans(tagged.spans)
      }
    }

    func visitPID(_ tagged: Span.Tagged) {
      if let pid = tagged.attributes.first {
        combiner.withFont(combiner.lastFont?.bold()) {
          combiner.append(
            Text("Reply")
          )
          combiner.append(
            Text(" #\(pid) ")
          )
        }

      }
    }

    func visitDefault(_ tagged: Span.Tagged) {
      visitSpans(tagged.spans)
    }

    spans.forEach(visit)

    return combiner.build()
  }
}
