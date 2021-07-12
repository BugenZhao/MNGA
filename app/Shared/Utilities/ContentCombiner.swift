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

  private let parent: ContentCombiner?
  private let postScroll: PostScrollModel
  private let fontModifier: (Font?) -> Font?
  private let colorModifier: (Color?) -> Color?

  private var subviews = [Subview]()
  private var envs = [String: String]()

  private var font: Font? {
    self.fontModifier(parent?.font)
  }
  private var color: Color? {
    self.colorModifier(parent?.color)
  }

  init(parent: ContentCombiner, font: @escaping (Font?) -> Font?, color: @escaping (Color?) -> Color?) {
    self.parent = parent
    self.postScroll = parent.postScroll
    self.fontModifier = font
    self.colorModifier = color
  }

  init(postScroll: PostScrollModel) {
    self.parent = nil
    self.postScroll = postScroll
    self.fontModifier = { _ in Font.callout }
    self.colorModifier = { _ in Color.primary }
  }

  private func append<V: View>(_ view: V) {
    let subview: Subview

    if view is Text {
      let text = (view as! Text)
        .font(self.font)
        .foregroundColor(self.color)
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
      tapAction = { withAnimation { self.postScroll.pid = pid } }
    }

    let view = HStack { combiner.buildView(); Spacer() }
      .padding(.small)
      .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(Color.systemGroupedBackground)
    ) .onTapGesture(perform: tapAction)

    self.append(view)
  }

  private func visit(bold: Span.Tagged) {
    let combiner = ContentCombiner(parent: self, font: { $0?.bold() }, color: { $0 })

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
    let combiner = ContentCombiner(parent: self, font: { $0 }, color: { _ in Color.accentColor })
    combiner.append(Text(Image(systemName: "person.fill")))
    combiner.visit(spans: uid.spans)
    self.append(combiner.build())
  }

  private func visit(pid: Span.Tagged) {
    if let pid = pid.attributes.first {
      let combiner = ContentCombiner(parent: self, font: { $0?.bold() }, color: { $0 })
      combiner.append(Text("Post"))
      combiner.append(Text(" #\(pid) "))
      self.append(combiner.build())
      self.envs["pid"] = pid
    }
  }

  private func visit(tid: Span.Tagged) {
    if let tid = tid.attributes.first {
      let combiner = ContentCombiner(parent: self, font: { $0?.bold() }, color: { $0 })
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
      let combiner = ContentCombiner(parent: self, font: { $0 }, color: { _ in Color.accentColor })
      let text = Text(Image(systemName: "link")) + Text(" ") + Text(displayString)
      combiner.append(text)

      let view = HStack {
        combiner.buildView().lineLimit(1)
        Spacer()
      } .padding(.small)
        .background(
        RoundedRectangle(cornerRadius: 12)
          .fill(Color.systemGroupedBackground)
      )

      if let url = URL(string: urlString) {
        let link = view.onTapGesture {
          UIApplication.shared.open(url)
        }
        self.append(link)
      } else {
        self.append(view)
      }
    }
  }

  private func visit(defaultTagged: Span.Tagged) {
    self.visit(spans: defaultTagged.spans)
  }
}
