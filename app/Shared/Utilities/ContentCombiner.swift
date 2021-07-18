//
//  ContentCombiner.swift
//  NGA
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI
import SwiftUIX

class ContentCombiner {
  enum Subview {
    case text(Text)
    case other(AnyView)
  }

  struct OtherStyles: OptionSet {
    let rawValue: Int
    static let underline = Self(rawValue: 1 << 0)
  }

  static private let palette: [String: Color] = [
    "red": .red,
    "green": .green,
    "blue": .blue,
  ]

  private let parent: ContentCombiner?
  private let postScroll: PostScrollModel?

  private let fontModifier: (Font?) -> Font?
  private let colorModifier: (Color?) -> Color?
  private let otherStylesModifier: (OtherStyles) -> OtherStyles

  private var subviews = [Subview]()
  private var envs = [String: String]()

  private var font: Font? {
    self.fontModifier(parent?.font)
  }
  private var color: Color? {
    self.colorModifier(parent?.color)
  }
  private var otherStyles: OtherStyles {
    self.otherStylesModifier(parent?.otherStyles ?? [])
  }

  init(
    parent: ContentCombiner,
    font: @escaping (Font?) -> Font? = { $0 },
    color: @escaping (Color?) -> Color? = { $0 },
    otherStyles: @escaping (OtherStyles) -> OtherStyles = { $0 }
  ) {
    self.parent = parent
    self.postScroll = parent.postScroll
    self.fontModifier = font
    self.colorModifier = color
    self.otherStylesModifier = otherStyles
  }

  init(postScroll: PostScrollModel?, defaultFont: Font, defaultColor: Color) {
    self.parent = nil
    self.postScroll = postScroll
    self.fontModifier = { _ in defaultFont }
    self.colorModifier = { _ in defaultColor }
    self.otherStylesModifier = { $0 }
  }

  private func styledText(_ text: Text, overridenFont: Font? = nil, overridenColor: Color? = nil) -> Text {
    var text: Text = text
      .font(overridenFont ?? self.font)
      .foregroundColor(overridenColor ?? self.color)

    if otherStyles.contains(.underline) {
      text = text.underline()
    }

    return text
  }

  private func append<V: View>(_ view: V) {
    let subview: Subview

    if view is Text {
      let text = self.styledText(view as! Text)
      subview = Subview.text(text)
    } else if view is AnyView {
      subview = Subview.other(view as! AnyView)
    } else {
      subview = Subview.other(AnyView(view))
    }

    self.subviews.append(subview)
  }

  private func append(_ subview: Subview) {
    self.subviews.append(subview)
  }

  private func build() -> Subview {
    var textBuffer: Text? = nil
    var results = [AnyView]()

    for subview in self.subviews {
      switch subview {
      case .text(let text):
        textBuffer = (textBuffer ?? Text("")) + text
      case .other(let view):
        if let tb = textBuffer {
          results.append(AnyView(tb))
          textBuffer = nil
        }
        results.append(view)
      }
    }

    if results.isEmpty {
      // text-only view
      return .text(textBuffer ?? Text(""))
    } else {
      // complex view
      if let tb = textBuffer { results.append(AnyView(tb)) }
      let stack = VStack(alignment: .leading) {
        ForEach(results.indices, id: \.self) { index in
          results[index]
        }
      }
      return .other(AnyView(stack))
    }
  }

  @ViewBuilder
  func buildView() -> some View {
    switch self.build() {
    case .text(let text):
      text
    case .other(let any):
      any
    }
  }

  func visit(spans: [Span]) {
    spans.forEach(visit(span:))
  }

  func visit(span: Span) {
    guard let value = span.value else { return }

    switch value {
    case .breakLine(_):
      self.append(Spacer().frame(height: 6))
    case .plain(let plain):
      self.visit(plain: plain)
    case .sticker(let sticker):
      self.visit(sticker: sticker)
    case .tagged(let tagged):
      self.visit(tagged: tagged)
    }
  }

  private func visit(plain: Span.Plain) {
    let text: Text
    if plain.text == "Post by " {
      text = Text("Post by") + Text(" ")
    } else {
      text = Text(plain.text)
    }
    self.append(text)
  }

  private func visit(sticker: Span.Sticker) {
    let name = sticker.name.replacingOccurrences(of: ":", with: "|")

    let view: Text?
    if let image = AppKitOrUIKitImage(named: name) {
      let renderingMode: Image.TemplateRenderingMode =
        name.starts(with: "ac") || name.starts(with: "a2") ? .template : .original
      view = Text(
        Image(image: image)
          .renderingMode(renderingMode)
      )
    } else {
      view = Text("[🐶\(sticker.name)]").foregroundColor(.secondary)
    }

    self.append(view)
  }

  private func visit(tagged: Span.Tagged) {
    switch tagged.tag {
    case "img":
      self.visit(image: tagged)
    case "quote":
      self.visit(quote: tagged)
    case "b":
      self.visit(bold: tagged)
    case "uid":
      self.visit(uid: tagged)
    case "pid":
      self.visit(pid: tagged)
    case "tid":
      self.visit(tid: tagged)
    case "url":
      self.visit(url: tagged)
    case "code":
      self.visit(code: tagged)
    case "u":
      self.visit(underlined: tagged)
    case "i":
      self.visit(italic: tagged)
    case "del":
      self.visit(deleted: tagged)
    case "color":
      self.visit(colored: tagged)
    case "size":
      self.visit(sized: tagged)
    case "collapse":
      self.visit(collapsed: tagged)
    default:
      self.visit(defaultTagged: tagged)
    }
  }

  private func visit(image: Span.Tagged) {
    guard let value = image.spans.first?.value else { return }
    guard case .plain(let plain) = value else { return }

    var urlText = plain.text
    if !urlText.contains("http") {
      urlText = "https://img.nga.178.com/attachments/" + urlText
    }
    guard let url = URL(string: urlText) else { return }

    let image = PostImageView(url: url)
    self.append(image)
  }

  private func visit(quote: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { _ in Font.subheadline }, color: { _ in Color.primary.opacity(0.9) })
    combiner.visit(spans: quote.spans)

    var tapAction: () -> Void = { }
    if let pid = combiner.envs["pid"] {
      tapAction = { withAnimation {
        if let postScroll = self.postScroll {
          postScroll.pid = pid
        }
      } }
    }

    let view = QuoteView(fullWidth: true) {
      combiner.buildView()
    } .onTapGesture(perform: tapAction)

    self.append(view)
  }

  private func visit(bold: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { $0?.bold() })

    if bold.spans.first?.plain.text.starts(with: "Reply to") == true {
      combiner.visit(quote: Span.Tagged.with {
        $0.spans = Array(bold.spans.dropFirst())
      })
    } else {
      combiner.visit(spans: bold.spans)
    }

    self.append(combiner.build())
  }

  private func visit(uid: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, color: { _ in Color.accentColor })
    combiner.append(Text(Image(systemName: "person.fill")))
    combiner.visit(spans: uid.spans)
    self.append(combiner.build())
  }

  private func visit(pid: Span.Tagged) {
    if let pid = pid.attributes.first {
      let combiner = ContentCombiner(parent: self, font: { $0?.bold() })
      combiner.append(Text("Post"))
      combiner.append(Text(" #\(pid) "))
      self.append(combiner.build())
      self.envs["pid"] = pid
    }
  }

  private func visit(tid: Span.Tagged) {
    if let tid = tid.attributes.first {
      let combiner = ContentCombiner(parent: self, font: { $0?.bold() })
      combiner.append(Text("Topic"))
      combiner.append(Text(" #\(tid) "))
      self.append(combiner.build())
      self.envs["pid"] = "0"
    }
  }

  private func visit(url: Span.Tagged) {
    let urlString: String?
    let displayString: String

    let innerString = url.spans.first?.plain.text
    if let u = url.attributes.first {
      urlString = u
      displayString = innerString ?? "Link"
    } else {
      urlString = innerString
      displayString = innerString ?? "Link"
    }

    if let urlString = urlString {
      let combiner = ContentCombiner(parent: self, font: { _ in Font.footnote }, color: { _ in Color.accentColor })
      let text = Text(Image(systemName: "link")) + Text(" ") + Text(displayString)
      combiner.append(text)

      let view = combiner.buildView().lineLimit(1)
        .padding(.small)
        .background(
        RoundedRectangle(cornerRadius: 12)
        #if os(iOS)
          .fill(Color.systemGroupedBackground)
        #endif
      )

      let link = Button(action: {
        if let url = URL(string: urlString) {
          #if os(iOS)
            UIApplication.shared.open(url)
          #elseif os(macOS)
            NSWorkspace.shared.open(url)
          #endif
        }
      }) {
        view
      } .buttonStyle(.plain)

      self.append(link)
    }
  }

  private func visit(code: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { _ in Font.system(.footnote, design: .monospaced) })
    combiner.visit(spans: code.spans)
    self.append(combiner.build())
  }

  private func visit(underlined: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, otherStyles: { $0.union(.underline) })
    combiner.visit(spans: underlined.spans)
    self.append(combiner.build())
  }

  private func visit(italic: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { $0?.italic() })
    combiner.visit(spans: italic.spans)
    self.append(combiner.build())
  }

  private func visit(deleted: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, color: { _ in Color.tertiaryLabel })
    combiner.visit(spans: deleted.spans)
    self.append(combiner.build())
  }

  private func visit(colored: Span.Tagged) {
    let color = colored.attributes.first.flatMap { Self.palette[$0] }
    let combiner = ContentCombiner(parent: self, color: { color ?? $0 })
    combiner.visit(spans: colored.spans)
    self.append(combiner.build())
  }

  private func visit(sized: Span.Tagged) {
    let scale = Double(sized.attributes.first?.trimmingCharacters(in: ["%"]) ?? "100") ?? 100.0
    let combiner = ContentCombiner(parent: self, font: {
      #if os(iOS)
        let baseSize = $0?.getTextStyle()?.defaultMetrics.size ?? Font.TextStyle.callout.defaultMetrics.size
      #elseif os(macOS)
        let baseSize = CGFloat(16.0)
      #endif
      let newSize = baseSize * CGFloat(scale / 100)
      return Font.custom("", fixedSize: newSize)
    })
    combiner.visit(spans: sized.spans)
    self.append(combiner.build())
  }

  private func visit(collapsed: Span.Tagged) {
    let title = collapsed.attributes.first ?? NSLocalizedString("Collapsed Content", comment: "")

    let combiner = ContentCombiner(parent: self)
    combiner.visit(spans: collapsed.spans)
    let content = combiner.buildView()

    let view = CollapsedContentView(title: title, content: { content })
    self.append(view)
  }

  private func visit(defaultTagged: Span.Tagged) {
    self.visit(spans: defaultTagged.spans)
  }
}
