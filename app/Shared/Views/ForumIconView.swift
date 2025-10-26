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
      .resizable()
      .renderingMode(.template)

    WebOrAsyncImage(url: URL(string: iconURL), placeholder: defaultIcon)
      .frame(width: size, height: size)
      .foregroundColor(.accentColor)
  }
}
