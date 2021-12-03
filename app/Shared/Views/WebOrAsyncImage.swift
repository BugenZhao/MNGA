//
//  WebOrAsyncImage.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/9/30.
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI

struct WebOrAsyncImage: View {
  let url: URL?
  let placeholder: Image?

  var body: some View {
    if #available(iOS 15.0, *), false { // TODO: use AsyncImage when ready
//      AsyncImage(url: url, content: { $0.resizable() }, placeholder: {
//          if let p = placeholder { p } else { ProgressView() }
//        })
    } else {
      if let url = url {
        let image = WebImage(url: url).resizable()
        if let p = placeholder {
          image.placeholder(p)
        } else {
          image.indicator(.activity)
        }
      } else {
        placeholder
      }
    }
  }
}
