//
//  ContentCombiner.swift
//  NGA
//
//  Created by Bugen Zhao on 7/11/21.
//

import Colorful
import Foundation
import SwiftUI
import SwiftUIX

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

  private static let palette: [String: Color] = [
    "skyblue": .skyBlue,
    "royalblue": .royalBlue,
    "blue": .init(hex: 0x0066BB),
    "darkblue": .darkBlue,
    "orange": .init(hex: 0xA06700),
    "orangered": .orangeRed,
    "crimson": .crimson,
    "red": .init(hex: 0xDD0000),
    "firebrick": .fireBrick,
    "darkred": .darkRed,
    "green": .init(hex: 0x3D9F0E),
    "limegreen": .limeGreen,
    "seagreen": .seaGreen,
    "teal": .init(hex: 0x008080),
    "deeppink": .deepPink,
    "tomato": .tomato,
    "coral": .coral,
    "purple": .init(hex: 0x800080),
    "indigo": .init(hex: 0x4B0082),
    "burlywood": .burleywood,
    "sandybrown": .sandyBrown,
    "chocolate": .chocolate,
    "sienna": .sienna,
    "silver": .init(hex: 0x888888),
  ]
  private static let ignoredTags = [
    "list",
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
    fontModifier(parent?.font)
  }

  private var color: Color? {
    colorModifier(parent?.color)
  }

  private var otherStyles: OtherStyles {
    otherStylesModifier(parent?.otherStyles ?? [])
  }

  private func setEnv(key: String, value: Any?) {
    envs[key] = value
  }

  private func setEnv(key: String, globalValue: Any?) {
    if parent == nil {
      envs[key] = globalValue
    } else {
      parent?.setEnv(key: key, globalValue: globalValue)
    }
  }

  private func getEnv(key: String) -> Any? {
    if let v = envs[key] {
      v
    } else {
      parent?.getEnv(key: key)
    }
  }

  private var inQuote: Bool {
    get { getEnv(key: "inQuote") != nil }
    set { setEnv(key: "inQuote", value: newValue ? "true" : nil) }
  }

  private var replyTo: PostId? {
    get { getEnv(key: "replyTo") as! PostId? }
    set { setEnv(key: "replyTo", value: newValue) }
  }

  private var selfId: PostId? {
    get { getEnv(key: "id") as! PostId? }
    set { setEnv(key: "id", value: newValue) }
  }

  init(
    parent: ContentCombiner?,
    font: @escaping (Font?) -> Font? = { $0 },
    color: @escaping (Color?) -> Color? = { $0 },
    otherStyles: @escaping (OtherStyles) -> OtherStyles = { $0 },
    overrideAlignment: HorizontalAlignment? = nil
  ) {
    self.parent = parent
    actionModel = parent?.actionModel
    fontModifier = font
    colorModifier = color
    otherStylesModifier = otherStyles
    alignment = overrideAlignment ?? parent?.alignment ?? .leading
  }

  init(actionModel: TopicDetailsActionModel?, id: PostId?, defaultFont: Font, defaultColor: Color, initialEnvs: [String: Any]? = nil) {
    parent = nil
    self.actionModel = actionModel
    fontModifier = { _ in defaultFont }
    colorModifier = { _ in defaultColor }
    otherStylesModifier = { $0 }
    alignment = .leading
    envs = initialEnvs ?? [:]

    selfId = id
  }

  private func styledText(_ text: Text, overridenFont: Font? = nil, overridenColor: Color? = nil) -> Text {
    var text: Text = text
      .font(overridenFont ?? font)
      .foregroundColor(overridenColor ?? color)

    if otherStyles.contains(.underline) {
      text = text.underline()
    }
    if otherStyles.contains(.strikethrough) {
      text = text.strikethrough()
    }

    return text
  }

  private func append(_ view: some View) {
    let subview: Subview

    if view is Text {
      let text = styledText(view as! Text)
      subview = Subview.text(text)
    } else if view is AnyView {
      subview = Subview.other(view as! AnyView)
    } else {
      subview = Subview.other(view.eraseToAnyView())
    }

    subviews.append(subview)
  }

  private func append(_ subview: Subview) {
    subviews.append(subview)
  }

  private func build() -> Subview {
    var textBuffer: Text?
    var results = [AnyView]()

    func tryAppendTextBuffer() {
      if let tb = textBuffer {
        let view = tb.eraseToAnyView()
        results.append(view)
        textBuffer = nil
      }
    }

    for subview in subviews {
      switch subview {
      case let .text(text):
        textBuffer = (textBuffer ?? Text("")) + text
      case .breakline:
        if textBuffer != nil {
          textBuffer = textBuffer! + Text("\n")
        }
      case let .other(view):
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
      let stack = VStack(alignment: alignment, spacing: 8) {
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
    switch build() {
    case let .text(text):
      text
    case .breakline:
      // not reached
      EmptyView()
    case let .other(any):
      any
    }
  }

  func visit(spans: some Sequence<Span>) {
    spans.forEach(visit(span:))
  }

  func visit(span: Span) {
    guard let value = span.value else { return }

    switch value {
    case .breakLine:
      append(.breakline)
    case let .plain(plain):
      visit(plain: plain)
    case let .sticker(sticker):
      visit(sticker: sticker)
    case let .tagged(tagged):
      visit(tagged: tagged)
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
    append(text)
  }

  private func visit(divider: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { _ in Font.headline }, color: { _ in Color.accentColor })
    if !divider.spans.isEmpty {
      combiner.append(Spacer().height(6))
      combiner.visit(spans: divider.spans)
    }
    combiner.append(Divider())
    let subview = combiner.build()
    append(subview)
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

    append(view)
  }

  private func visit(tagged: Span.Tagged) {
    switch tagged.tag {
    case "_divider":
      visit(divider: tagged)
    case "img":
      visit(image: tagged)
    case "quote":
      visit(quote: tagged)
    case "b":
      visit(bold: tagged)
    case "uid":
      visit(uid: tagged)
    case "pid":
      visit(pid: tagged)
    case "tid":
      visit(tid: tagged)
    case "url":
      visit(url: tagged)
    case "code":
      visit(code: tagged)
    case "u":
      visit(underlined: tagged)
    case "i":
      visit(italic: tagged)
    case "del":
      visit(deleted: tagged)
    case "color":
      visit(colored: tagged)
    case "size":
      visit(sized: tagged)
    case "collapse":
      visit(collapsed: tagged)
    case "flash":
      visit(flash: tagged)
    case "attach":
      visit(attach: tagged)
    case "align":
      visit(align: tagged)
    case "_mnga":
      visit(mnga: tagged)
    default:
      visit(defaultTagged: tagged)
    }
  }

  private func visit(image: Span.Tagged) {
    guard let value = image.spans.first?.value else { return }
    guard case let .plain(plain) = value else { return }

    let urlText = plain.text
    guard let url = URL(string: urlText, relativeTo: URLs.attachmentBase) else { return }

    let onlyThumbs = inQuote && replyTo != nil
    let image = ContentImageView(url: url, onlyThumbs: onlyThumbs)
    append(image)
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
    var lineLimit: Int?

    if let pid = metaCombiner.replyTo, let uid = metaCombiner.getEnv(key: "uid") as! String? {
      if let model = actionModel, let id = selfId {
        model.recordReply(from: id, to: pid)
        tapAction = { model.showReplyChain(from: id) }
        lineLimit = 5 // TODO: add an option
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
    }.lineLimit(lineLimit)
    append(view)
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

    append(combiner.build())
  }

  private func visit(uid: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, color: { _ in Color.accentColor })
    combiner.append(Text(Image(systemName: "person.fill")))
    combiner.visit(spans: uid.spans)

    var name: String?
    if case let .plain(p) = uid.spans.first?.value, p.text != "" {
      name = p.text
      setEnv(key: "username", globalValue: p.text)
    }
    if let uid = uid.attributes.first {
      setEnv(key: "uid", globalValue: uid)
    } else if let name { // treat raw name as id, mainly for anonymous users
      setEnv(key: "uid", globalValue: name)
    }

    append(combiner.build())
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
      replyTo = id
    }
    append(combiner.build())
  }

  private func visit(tid: Span.Tagged) {
//    let combiner = ContentCombiner(parent: self, font: { $0?.bold() })
//    combiner.append(Text("Topic"))
    if let tid = tid.attributes.first {
//      combiner.append(Text(" #\(tid) "))
      replyTo = .with {
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
    visit(url: url, defaultTitle: Text("Topic \(id)"))
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
      guard let urlString else { return }
      guard let url = URL(string: urlString, relativeTo: URLs.base) else { return }

      switch url.mngaNavigationIdentifier {
      case let .topicID(tid, _):
        self.actionModel?.navigateToTid = tid
      case let .forumID(id):
        self.actionModel?.navigateToForum = Forum.with { $0.id = id }
      case .none:
        OpenURLModel.shared.open(url: url)
      }
    }

    append(link)
  }

  private func visit(code: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { _ in Font.system(.footnote, design: .monospaced) })
    combiner.visit(spans: code.spans)
    append(combiner.build())
  }

  private func visit(underlined: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, otherStyles: { $0.union(.underline) })
    combiner.visit(spans: underlined.spans)
    append(combiner.build())
  }

  private func visit(italic: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { $0?.italic() })
    combiner.visit(spans: italic.spans)
    append(combiner.build())
  }

  private func visit(deleted: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, otherStyles: { $0.union(.strikethrough) })
    combiner.visit(spans: deleted.spans)
    append(combiner.build())
  }

  private func visit(colored: Span.Tagged) {
    let color = colored.attributes.first.flatMap { Self.palette[$0] }
    let combiner = ContentCombiner(parent: self, color: { color ?? $0 })
    combiner.visit(spans: colored.spans)
    append(combiner.build())
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
    append(combiner.build())
  }

  private func visit(collapsed: Span.Tagged) {
    let title = "\(collapsed.attributes.first ?? "Collapsed Content".localized)..."

    let combiner = ContentCombiner(parent: self)
    combiner.visit(spans: collapsed.spans)
    let content = combiner.buildView()

    let view = CollapsedContentView(title: title, content: { content })
    append(view)
  }

  private func visit(flash: Span.Tagged) {
    switch flash.attributes.first {
    case "video":
      visitFlash(video: flash)
    case "audio":
      visitFlash(audio: flash)
    default: // treat as video
      visitFlash(video: flash)
    }
  }

  private func visitFlash(video: Span.Tagged) {
    guard let value = video.spans.first?.value else { return }
    guard case let .plain(plain) = value else { return }

    let urlText = plain.text
    guard let url = URL(string: urlText, relativeTo: URLs.attachmentBase) else { return }

    let link = ContentButtonView(icon: "film", title: Text("View Video"), inQuote: inQuote) {
      OpenURLModel.shared.open(url: url, inApp: true)
    }
    append(link)
  }

  private func visitFlash(audio: Span.Tagged) {
    guard let value = audio.spans.first?.value else { return }
    guard case let .plain(plain) = value else { return }

    let tokens = plain.text.split(separator: "?").map(String.init)
    let duration = tokens.last { $0.contains("duration") }

    guard let urlText = tokens.first else { return }
    guard let url = URL(string: urlText, relativeTo: URLs.attachmentBase) else { return }

    let title = if let duration = extractQueryParams(query: duration ?? "", param: "duration") {
      Text(duration)
    } else {
      Text("Audio")
    }

    let link = ContentButtonView(icon: "waveform", title: title, inQuote: inQuote) {
      OpenURLModel.shared.open(url: url, inApp: true)
    }
    append(link)
  }

  private func visit(attach: Span.Tagged) {
    guard let value = attach.spans.first?.value else { return }
    guard case let .plain(plain) = value else { return }

    let urlText = plain.text
    guard let url = URL(string: urlText, relativeTo: URLs.attachmentBase) else { return }

    let link = ContentButtonView(icon: "paperclip", title: Text("View Attachment"), inQuote: inQuote) {
      OpenURLModel.shared.open(url: url, inApp: true)
    }
    append(link)
  }

  private func visit(align: Span.Tagged) {
    var alignment: HorizontalAlignment?
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
      append(view)
    } else if align.attributes.first == "left" {
      let view = HStack {
        inner
        Spacer()
      }
      append(view)
    } else if align.attributes.first == "right" {
      let view = HStack {
        Spacer()
        inner
      }
      append(view)
    } else {
      append(inner)
    }
  }

  private func visit(mnga: Span.Tagged) {
    guard let fn = mnga.attributes.first else { return }
    switch fn {
    case "version":
      append(Text(getVersionWithBuild()))
    default:
      break
    }
  }

  private func visit(defaultTagged: Span.Tagged) {
    if Self.ignoredTags.contains(defaultTagged.tag) {
      visit(spans: defaultTagged.spans)
      return
    }

    let combiner = ContentCombiner(parent: self)
    let tagFont = Font.system(.footnote, design: .monospaced)
    combiner.append(Text("[\(defaultTagged.tag)]").font(tagFont))
    combiner.visit(spans: defaultTagged.spans)
    combiner.append(Text("[/\(defaultTagged.tag)]").font(tagFont))
    append(combiner.build())
  }
}
