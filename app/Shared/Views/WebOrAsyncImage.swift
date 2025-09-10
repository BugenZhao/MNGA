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
    if let url {
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
