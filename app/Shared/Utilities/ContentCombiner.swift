//
//  ContentCombiner.swift
//  NGA
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI
import SwiftUIX
import Colorful

class ContentCombiner {
  enum Subview {
    case text(Text)
    case breakline
    case other(AnyView)
  }

  struct OtherStyles: OptionSet {
    let rawValue: Int

    static let underline = Self(rawValue: 1 << 0)
    static let strikethrough = Self(rawValue: 1 << 1)
  }

  static private let palette: [String: Color] = [
    "skyblue": .skyBlue,
    "royalblue": .royalBlue,
    "blue": .init(hex: 0x0066bb),
    "darkblue": .darkBlue,
    "orange": .init(hex: 0xa06700),
    "orangered": .orangeRed,
    "crimson": .crimson,
    "red": .init(hex: 0xdd0000),
    "firebrick": .fireBrick,
    "darkred": .darkRed,
    "green": .init(hex: 0x3d9f0e),
    "limegreen": .limeGreen,
    "seagreen": .seaGreen,
    "teal": .init(hex: 0x008080),
    "deeppink": .deepPink,
    "tomato": .tomato,
    "coral": .coral,
    "purple": .init(hex: 0x800080),
    "indigo": .init(hex: 0x4b0082),
    "burlywood": .burleywood,
    "sandybrown": .sandyBrown,
    "chocolate": .chocolate,
    "sienna": .sienna,
    "silver": .init(hex: 0x888888),
  ]
  static private let ignoredTags = [
    "list"
  ]

  private let parent: ContentCombiner?
  private let actionModel: TopicDetailsActionModel?

  private let fontModifier: (Font?) -> Font?
  private let colorModifier: (Color?) -> Color?
  private let otherStylesModifier: (OtherStyles) -> OtherStyles
  private let alignment: HorizontalAlignment

  private var subviews = [Subview]()
  private var envs = [String: Any]()

  private var font: Font? {
    self.fontModifier(parent?.font)
  }
  private var color: Color? {
    self.colorModifier(parent?.color)
  }
  private var otherStyles: OtherStyles {
    self.otherStylesModifier(parent?.otherStyles ?? [])
  }

  private func setEnv(key: String, value: Any?) {
    self.envs[key] = value
  }
  private func setEnv(key: String, globalValue: Any?) {
    if self.parent == nil {
      self.envs[key] = globalValue
    } else {
      self.parent?.setEnv(key: key, globalValue: globalValue)
    }
  }
  private func getEnv(key: String) -> Any? {
    if let v = self.envs[key] {
      return v
    } else {
      return self.parent?.getEnv(key: key)
    }
  }

  private var inQuote: Bool {
    get { self.getEnv(key: "inQuote") != nil }
    set { self.setEnv(key: "inQuote", value: newValue ? "true" : nil) }
  }
  private var replyTo: PostId? {
    get { self.getEnv(key: "replyTo") as! PostId? }
    set { self.setEnv(key: "replyTo", value: newValue) }
  }
  private var selfId: PostId? {
    get { self.getEnv(key: "id") as! PostId? }
    set { self.setEnv(key: "id", value: newValue) }
  }

  init(
    parent: ContentCombiner?,
    font: @escaping (Font?) -> Font? = { $0 },
    color: @escaping (Color?) -> Color? = { $0 },
    otherStyles: @escaping (OtherStyles) -> OtherStyles = { $0 },
    overrideAlignment: HorizontalAlignment? = nil
  ) {
    self.parent = parent
    self.actionModel = parent?.actionModel
    self.fontModifier = font
    self.colorModifier = color
    self.otherStylesModifier = otherStyles
    self.alignment = overrideAlignment ?? parent?.alignment ?? .leading
  }

  init(actionModel: TopicDetailsActionModel?, id: PostId?, defaultFont: Font, defaultColor: Color, initialEnvs: [String: Any]? = nil) {
    self.parent = nil
    self.actionModel = actionModel
    self.fontModifier = { _ in defaultFont }
    self.colorModifier = { _ in defaultColor }
    self.otherStylesModifier = { $0 }
    self.alignment = .leading
    self.envs = initialEnvs ?? [:]

    self.selfId = id
  }

  private func styledText(_ text: Text, overridenFont: Font? = nil, overridenColor: Color? = nil) -> Text {
    var text: Text = text
      .font(overridenFont ?? self.font)
      .foregroundColor(overridenColor ?? self.color)

    if otherStyles.contains(.underline) {
      text = text.underline()
    }
    if otherStyles.contains(.strikethrough) {
      text = text.strikethrough()
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
      subview = Subview.other(view.eraseToAnyView())
    }

    self.subviews.append(subview)
  }

  private func append(_ subview: Subview) {
    self.subviews.append(subview)
  }

  private func build() -> Subview {
    var textBuffer: Text? = nil
    var results = [AnyView]()

    func tryAppendTextBuffer() {
      if let tb = textBuffer {
        let view = tb.eraseToAnyView()
        results.append(view)
        textBuffer = nil
      }
    }

    for subview in self.subviews {
      switch subview {
      case .text(let text):
        textBuffer = (textBuffer ?? Text("")) + text
      case .breakline:
        if textBuffer != nil {
          textBuffer = textBuffer! + Text("\n")
        }
      case .other(let view):
        tryAppendTextBuffer()
        results.append(view)
      }
    }

    if results.isEmpty {
      // text-only view
      return .text(textBuffer ?? Text(""))
    } else {
      // complex view
      tryAppendTextBuffer()
      let stack = VStack(alignment: self.alignment, spacing: 8) {
        ForEach(results.indices, id: \.self) { index in
          results[index]
            .fixedSize(horizontal: false, vertical: true)
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
    case .breakline:
      // not reached
      EmptyView()
    case .other(let any):
      any
    }
  }

  func visit<S: Sequence>(spans: S) where S.Element == Span {
    spans.forEach(visit(span:))
  }

  func visit(span: Span) {
    guard let value = span.value else { return }

    switch value {
    case .breakLine(_):
      self.append(.breakline)
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

    var plain = plain
    plain.text = plain.text.replacingOccurrences(of: "[*]", with: "→ ")

    if plain.text == "Post by " {
      text = Text("Post by") + Text(" ")
    } else {
      text = Text(plain.text)
    }
    self.append(text)
  }

  private func visit(divider: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { _ in Font.headline }, color: { _ in Color.accentColor })
    if !divider.spans.isEmpty {
      combiner.append(Spacer().height(6))
      combiner.visit(spans: divider.spans)
    }
    combiner.append(Divider())
    let subview = combiner.build()
    self.append(subview)
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
    case "_divider":
      self.visit(divider: tagged)
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
    case "flash":
      self.visit(flash: tagged)
    case "align":
      self.visit(align: tagged)
    default:
      self.visit(defaultTagged: tagged)
    }
  }

  private func visit(image: Span.Tagged) {
    guard let value = image.spans.first?.value else { return }
    guard case .plain(let plain) = value else { return }

    let urlText = plain.text
    guard let url = URL(string: urlText, relativeTo: URLs.attachmentBase) else { return }

    let onlyThumbs = self.inQuote && self.replyTo != nil
    let image = ContentImageView(url: url, onlyThumbs: onlyThumbs)
    self.append(image)
  }

  private func visit(quote: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { _ in Font.subheadline }, color: { _ in Color.primary.opacity(0.9) })
    combiner.inQuote = true

    let spans = quote.spans
    let metaSpans = spans.prefix { $0.value != .breakLine(.init()) }
    let metaCombiner = ContentCombiner(parent: nil)
    metaCombiner.inQuote = true
    metaCombiner.visit(spans: metaSpans)

    var tapAction: (() -> Void)?
    var lineLimit: Int? = nil

    if let pid = metaCombiner.replyTo, let uid = metaCombiner.getEnv(key: "uid") as! String? {
      if let model = self.actionModel, let id = self.selfId {
        model.recordReply(from: id, to: pid)
        tapAction = { model.showReplyChain(from: id) }
        lineLimit = 5 // todo: add an option
      }

      let name = metaCombiner.getEnv(key: "username") as! String?
      let userView = QuoteUserView(uid: uid, nameHint: name, action: tapAction)
      combiner.append(userView)
      combiner.envs = metaCombiner.envs
      let contentSpans = spans[metaSpans.count...]
      combiner.visit(spans: contentSpans)
    } else {
      // failed to extract metadata, use plain formatting
      combiner.visit(spans: spans)
    }

    let view = QuoteView(fullWidth: true) {
      combiner.buildView()
    } .lineLimit(lineLimit)
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

    var name: String?
    if case .plain(let p) = uid.spans.first?.value, p.text != "" {
      name = p.text
      self.setEnv(key: "username", globalValue: p.text)
    }
    if let uid = uid.attributes.first {
      self.setEnv(key: "uid", globalValue: uid)
    } else if let name = name { // treat raw name as id, mainly for anonymous users
      self.setEnv(key: "uid", globalValue: name)
    }

    self.append(combiner.build())
  }

  private func visit(pid: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { $0?.bold() })
    combiner.append(Text("Post"))
    if pid.attributes.count > 2 {
      let id = PostId.with {
        $0.pid = pid.attributes[0]
        $0.tid = pid.attributes[1]
      }
      combiner.append(Text(" #\(id.pid) "))
      self.replyTo = id
    }
    self.append(combiner.build())
  }

  private func visit(tid: Span.Tagged) {
//    let combiner = ContentCombiner(parent: self, font: { $0?.bold() })
//    combiner.append(Text("Topic"))
    if let tid = tid.attributes.first {
//      combiner.append(Text(" #\(tid) "))
      self.replyTo = .with {
        $0.pid = "0"
        $0.tid = tid
      }
    }
//    self.append(combiner.build())
    guard let id = tid.attributes.first else { return }
    let url = Span.Tagged.with {
      $0.spans = tid.spans
      $0.attributes = ["read.php?tid=\(id)"]
    }
    self.visit(url: url, defaultTitle: Text("Topic \(id)"))
  }

  private func visit(url: Span.Tagged, defaultTitle: Text? = nil) {
    let urlString: String?

    let combiner = ContentCombiner(parent: self, font: { _ in .footnote }, color: { _ in .accentColor })
    combiner.visit(spans: url.spans)
    let innerView = url.spans.isEmpty ? defaultTitle?.eraseToAnyView() : combiner.buildView().eraseToAnyView()

    if let u = url.attributes.first {
      urlString = u
    } else {
      urlString = url.spans.first?.plain.text
    }

    let link = ContentButtonView(icon: "link", title: innerView, inQuote: inQuote) {
      guard let urlString = urlString else { return }
      guard let url = URL(string: urlString, relativeTo: URLs.base) else { return }

      switch url.mngaNavigationIdentifier {
      case .topicID(let tid, _):
        self.actionModel?.navigateToTid = tid
      case .forumID(let id):
        self.actionModel?.navigateToForum = Forum.with { $0.id = id }
      case .none:
        OpenURLModel.shared.open(url: url)
      }
    }

    self.append(link)
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
    let combiner = ContentCombiner(parent: self, otherStyles: { $0.union(.strikethrough) })
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
    let title = "\(collapsed.attributes.first ?? "Collapsed Content".localized)..."

    let combiner = ContentCombiner(parent: self)
    combiner.visit(spans: collapsed.spans)
    let content = combiner.buildView()

    let view = CollapsedContentView(title: title, content: { content })
    self.append(view)
  }

  private func visit(flash: Span.Tagged) {
    switch flash.attributes.first {
    case "video":
      self.visitFlash(video: flash)
    case "audio":
      self.visitFlash(audio: flash)
    default: // treat as video
      self.visitFlash(video: flash)
    }
  }

  private func visitFlash(video: Span.Tagged) {
    guard let value = video.spans.first?.value else { return }
    guard case .plain(let plain) = value else { return }

    let urlText = plain.text
    guard let url = URL(string: urlText, relativeTo: URLs.attachmentBase) else { return }

    let link = ContentButtonView(icon: "film", title: Text("View Video"), inQuote: inQuote) {
      OpenURLModel.shared.open(url: url, inApp: true)
    }
    self.append(link)
  }

  private func visitFlash(audio: Span.Tagged) {
    guard let value = audio.spans.first?.value else { return }
    guard case .plain(let plain) = value else { return }

    let tokens = plain.text.split(separator: "?").map(String.init)
    let duration = tokens.last { $0.contains("duration") }

    guard let urlText = tokens.first else { return }
    guard let url = URL(string: urlText, relativeTo: URLs.attachmentBase) else { return }

    let title: Text
    if let duration = extractQueryParams(query: duration ?? "", param: "duration") {
      title = Text(duration)
    } else {
      title = Text("Audio")
    }

    let link = ContentButtonView(icon: "waveform", title: title, inQuote: inQuote) {
      OpenURLModel.shared.open(url: url, inApp: true)
    }
    self.append(link)
  }

  private func visit(align: Span.Tagged) {
    var alignment: HorizontalAlignment? = nil
    if align.attributes.first == "center" {
      alignment = .center
    } else if align.attributes.first == "left" {
      alignment = .leading
    } else if align.attributes.first == "right" {
      alignment = .trailing
    }

    let combiner = ContentCombiner(parent: self, overrideAlignment: alignment)
    combiner.visit(spans: align.spans)

    let inner = combiner.buildView()
    if align.attributes.first == "center" {
      let view = HStack {
        Spacer()
        inner
        Spacer()
      }
      self.append(view)
    } else if align.attributes.first == "left" {
      let view = HStack {
        inner
        Spacer()
      }
      self.append(view)
    } else if align.attributes.first == "right" {
      let view = HStack {
        Spacer()
        inner
      }
      self.append(view)
    } else {
      self.append(inner)
    }
  }

  private func visit(defaultTagged: Span.Tagged) {
    if Self.ignoredTags.contains(defaultTagged.tag) {
      self.visit(spans: defaultTagged.spans)
      return
    }

    let combiner = ContentCombiner(parent: self)
    let tagFont = Font.system(.footnote, design: .monospaced)
    combiner.append(Text("[\(defaultTagged.tag)]").font(tagFont))
    combiner.visit(spans: defaultTagged.spans)
    combiner.append(Text("[/\(defaultTagged.tag)]").font(tagFont))
    self.append(combiner.build())
  }
}
