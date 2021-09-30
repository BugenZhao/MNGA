//
//  ForumIconView.swift
//  ForumIconView
//
//  Created by Bugen Zhao on 8/17/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct ForumIconView: View {
  let iconURL: String

  var body: some View {
    let defaultIcon = Image("default_forum_icon")
      .resizable()

    if let url = URL(string: iconURL) {
      WebImage(url: url)
        .resizable()
        .placeholder(defaultIcon)
        .frame(width: 28, height: 28)
    } else {
      defaultIcon
        .frame(width: 28, height: 28)
    }
  }
}
