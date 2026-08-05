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
  @ScaledMetric var size: CGFloat = 28

  let iconURL: String

  var body: some View {
    let defaultIcon = Image(.defaultForumIcon)
      .renderingMode(.template)
    let url = URLs.resourceURL(iconURL)

    WebImage(url: url) {
      ($0.image ?? defaultIcon).resizable()
    }
    .frame(width: size, height: size)
    .foregroundColor(.accentColor)
    .id("forum-icon-\(url?.absoluteString ?? "")") // workaround not updating when url changes from nil to valid
  }
}
