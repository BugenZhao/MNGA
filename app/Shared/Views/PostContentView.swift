//
//  PostContentView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

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

struct PostContentView: View, Equatable {
  let spans: [Span]
  let defaultFont: Font
  let defaultColor: Color

  init(spans: [Span], defaultFont: Font = .callout, defaultColor: Color = .primary) {
    self.spans = spans
    self.defaultFont = defaultFont
    self.defaultColor = defaultColor
  }

  @OptionalEnvironmentObject<TopicDetailsActionModel> var actionModel

  var body: some View {
    let combiner = ContentCombiner(actionModel: actionModel, defaultFont: defaultFont, defaultColor: defaultColor)
    combiner.visit(spans: spans)
    return combiner.buildView()
  }

  static func == (lhs: PostContentView, rhs: PostContentView) -> Bool {
    return lhs.spans == rhs.spans
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
      PostContentView(spans: spans + [image])
    }
    #if os(iOS)
      .listStyle(GroupedListStyle())
    #endif
    .preferredColorScheme(.dark)
  }
}
