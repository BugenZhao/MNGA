//
//  PostContentView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI
import SwiftUIX

struct PostImageView: View {
  let url: URL
  let isOpenSourceStickers: Bool

  @EnvironmentObject var viewingImage: ViewingImageModel
  @State var overlayImage: PlatformImage?

  init(url: URL) {
    self.url = url
    self.isOpenSourceStickers = openSourceStickersNames.contains(url.lastPathComponent)
  }

  var body: some View {
    if isOpenSourceStickers {
      WebImage(url: url)
        .resizable()
        .placeholder {
        ProgressView()
          .frame(height: 50)
      }
        .aspectRatio(contentMode: .fit)
        .frame(width: 50, height: 50)
        .background(Color.white)
    } else {
      WebImage(url: url)
        .onSuccess { image, _, _ in
          DispatchQueue.main.async {
            self.overlayImage = image
          }
        }
        .resizable()
        .indicator(.activity)
        .scaledToFit()
        .onTapGesture { self.viewingImage.show(image: self.overlayImage) }
    }
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
      self[keyPath: target].append(AnyView(Spacer().frame(height: 4)))
    }
  }

  func appendPID(_ pid: String) {
    guard target == \.quoteViews else { return }
    self.pid = pid
    self.append(Text("Reply"))
    self.append(Text(" #\(pid) "))
  }

  func appendSticker(_ sticker: Span.Sticker) {
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

struct PostContentView: View {
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

      switch value {
      case .breakLine(_):
        combiner.appendBreakLine()
      case .plain(let plain):
        combiner.append(Text(plain.text))
      case .sticker(let sticker):
        combiner.appendSticker(sticker)
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
    }

    func visitImage(_ tagged: Span.Tagged) {
      guard let value = tagged.spans.first?.value else { return }
      guard case .plain(let plain) = value else { return }
      var urlText = plain.text
      if !urlText.contains("http") {
        urlText = "https://img.nga.178.com/attachments/" + urlText
      }
      guard let url = URL(string: urlText) else { return }

      let image = PostImageView(url: url)

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
        if tagged.spans.first?.plain.text.starts(with: "Post to") == true {
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
            Text("Post")
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


struct PostContentView_Previews: PreviewProvider {
  static var spans: [Span] {
    let sticker = Span.with { $0.sticker = .with { s in s.name = "a2:你看看你" } }
    let sticker2 = Span.with { $0.sticker = .with { s in s.name = "a2:doge" } }
    let sticker3 = Span.with { $0.sticker = .with { s in s.name = "pg:战斗力" } }
    let plain = Span.with { $0.plain = .with { p in p.text = "你看看他，再看看你自己。" } }
    let imageStickerUrl = Span.with { $0.plain = .with { p in p.text = "http://img.nga.178.com/attachments/mon_201209/14/-47218_5052c104b8e27.png" } }
    let bold = Span.with {
      $0.tagged = .with { t in
        t.tag = "b"
        t.spans = [plain]
      }
    }
    let imageSticker = Span.with {
      $0.tagged = .with { t in
        t.tag = "img"
        t.spans = [imageStickerUrl]
      }
    }

    return [
      plain, sticker, plain, bold, sticker2, plain, sticker3,
      plain, plain, imageSticker, plain,
    ]
  }

  static var previews: some View {
    let imageUrl = Span.with { $0.plain = .with { p in p.text = "./mon_202107/03/-7Q2o-aumgK2eT1kShs-120.jpg.medium.jpg" } }
    let image = Span.with {
      $0.tagged = .with { t in
        t.tag = "img"
        t.spans = [imageUrl]
      }
    }

    ScrollView {
      PostContentView(spans: spans + [image])
    }
  }
}
