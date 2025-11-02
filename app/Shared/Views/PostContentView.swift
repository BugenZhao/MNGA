//
//  PostContentView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Colorful
import Foundation
import SwiftUI
import SwiftUIX

struct InRealPostKey: EnvironmentKey {
  static let defaultValue: Bool = true
}

extension EnvironmentValues {
  var inRealPost: Bool {
    get { self[InRealPostKey.self] }
    set { self[InRealPostKey.self] = newValue }
  }
}

enum PostFontSize {
  // Used in posts.
  case small
  // Used in post comments and signatures.
  // Though the code path is not unified yet, this will also be used for quotes.
  case normal
}

struct PostContentView<S: Sequence & Hashable>: View where S.Element == Span {
  @StateObject var pref = PreferencesStorage.shared

  let spans: S
  let error: String?
  let id: PostId?
  let postDate: UInt64?
  let authorId: String?
  let fontSize: PostFontSize
  let defaultColor: Color
  let initialInQuote: Bool

  var defaultFont: Font {
    let useLargerFont = pref.postRowLargerFont

    return switch fontSize {
    case .small:
      useLargerFont ? .callout : .subheadline
    case .normal:
      useLargerFont ? .body : .callout
    }
  }

  init(
    spans: S,
    error: String? = nil,
    id: PostId? = nil,
    postDate: UInt64? = nil,
    authorId: String? = nil,
    fontSize: PostFontSize = .normal,
    defaultColor: Color = .primary,
    initialInQuote: Bool = false
  ) {
    self.spans = spans
    self.error = error
    self.id = id
    self.postDate = postDate
    self.authorId = authorId
    self.fontSize = fontSize
    self.defaultColor = defaultColor
    self.initialInQuote = initialInQuote
  }

  @EnvironmentObject<TopicDetailsActionModel>.Optional var actionModel

  var main: some View {
    var combiner = ContentCombiner(
      actionModel: actionModel,
      id: id,
      postDate: postDate,
      defaultFont: defaultFont,
      defaultColor: defaultColor
    )
    if initialInQuote {
      combiner.inQuote = true
    }
    if let context = DiceRoller.Context(authorIdString: authorId, topicIdString: id?.tid, postIdString: id?.pid) {
      combiner.diceContext = context
    }

    combiner.visit(spans: spans)
    return combiner.buildView()
  }

  var body: some View {
    VStack(alignment: .leading) {
      if let error, !error.isEmpty {
        QuoteView(fullWidth: true) {
          Text("Bad or Unsupported Post Content Format")
            .bold()
            + Text("\n") +
            Text(error)
            .font(.system(.footnote, design: .monospaced))
        }.font(.footnote)
          .foregroundColor(.orangeRed)
      }
      main
    }.fixedSize(horizontal: false, vertical: true)
      .equatable(by: spans.hashValue)
  }
}

extension PostContentView where S == [Span] {
  init(
    content: PostContent,
    id: PostId? = nil,
    postDate: UInt64? = nil,
    authorId: String? = nil,
    fontSize: PostFontSize = .normal,
    defaultColor: Color = .primary,
    initialInQuote: Bool = false
  ) {
    self.init(
      spans: content.spans,
      error: content.error,
      id: id,
      postDate: postDate,
      authorId: authorId,
      fontSize: fontSize,
      defaultColor: defaultColor,
      initialInQuote: initialInQuote
    )
  }

  init(post: Post) {
    self.init(
      content: post.content,
      id: post.id,
      postDate: post.postDate,
      authorId: post.authorID,
    )
  }

  init(
    lightPost: LightPost,
    initialInQuote: Bool = false
  ) {
    self.init(
      content: lightPost.content,
      id: lightPost.id,
      postDate: lightPost.postDate,
      authorId: lightPost.authorID,
      initialInQuote: initialInQuote
    )
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
    let quote = Span.with {
      $0.tagged = .with { t in
        t.tag = "quote"
        t.spans = [plain, sticker]
      }
    }
    let nestingQuote = Span.with {
      $0.tagged = .with { t in
        t.tag = "quote"
        t.spans = [quote, plain]
      }
    }
    let url = Span.with {
      $0.tagged = .with { t in
        t.tag = "url"
        t.spans = [imageStickerUrl]
      }
    }

    return [
      quote, nestingQuote,
      plain, sticker, plain, bold, sticker2, plain, sticker3,
      url,
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

    List {
      PostContentView(spans: spans + [image], error: "Test error")
    }
    .mayGroupedListStyle()
    .preferredColorScheme(.dark)
  }
}
