//
//  RichTextView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import RemoteImage

struct RichTextView: View {
  let spans: [Span]

  var body: some View {
    let views = buildViews()

    VStack(alignment: .leading) {
      ForEach(views.indices) { index in
        views[index]
      }
    }
  }

  func buildViews() -> [AnyView] {
    var views = [AnyView]()

    func visitSpans(_ spans: [Span]) {
      spans.forEach(visit)
    }

    func visit(_ span: Span) {
      guard let value = span.value else { return }

      switch value {
      case .breakLine(_):
        views.append(AnyView(
          Text("")
          ))
      case .plain(let plain):
        views.append(AnyView(
          Text(plain.text)
          ))
      case .sticker(let sticker):
        views.append(AnyView(
          Text(sticker.name)
          ))
      case .tagged(let tagged):
        switch tagged.tag {
        case "img":
          visitImage(tagged)
        default:
          visitDefault(tagged)
        }
      }
    }

    func visitImage(_ tagged: Span.Tagged) {
      guard let value = tagged.spans.first?.value else { return }
      guard case .plain(let plain) = value else { return }
      guard let url = URL(string: plain.text) else { return }

      let image = RemoteImage(
        type: .url(url),
        errorView: { e in Text("\(e.localizedDescription): \(url)") },
        imageView: { $0 },
        loadingView: { ProgressView() }
      )
      views.append(AnyView(HStack {
        Spacer()
        image
        Spacer()
      }))
    }

    func visitQuote(_ tagged: Span.Tagged) {
    }

    func visitDefault(_ tagged: Span.Tagged) {
      visitSpans(tagged.spans)
    }

    spans.forEach(visit)
    return views
  }
}
