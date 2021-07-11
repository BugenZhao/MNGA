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

struct PostContentView: View, Equatable {
  let spans: [Span]

  var body: some View {
    let combiner = ContentCombiner()
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
    } .listStyle(GroupedListStyle())
      .preferredColorScheme(.dark)
  }
}
