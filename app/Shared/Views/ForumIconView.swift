//
//  ForumIconView.swift
//  ForumIconView
//
//  Created by Bugen Zhao on 8/17/21.
//

import Foundation
import SDWebImageSwiftUI
import SwiftUI

struct ForumIconView: View {
  let iconURL: String

  var body: some View {
    let defaultIcon = Image("default_forum_icon")
      .resizable()
      .renderingMode(.template)

    WebOrAsyncImage(url: URL(string: iconURL), placeholder: defaultIcon)
      .frame(width: 28, height: 28)
      .foregroundColor(.accentColor)
  }
}
