//
//  TopicListPlaceholderView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI

struct TopicListPlaceholderView: View {
  var body: some View {
    VStack {
      Image(systemName: "list.bullet.rectangle.portrait")
        .font(.largeTitle)
      Spacer()
        .frame(height: 8)
      Text("Select a forum in sidebar")
        .font(.callout)
    } .foregroundColor(.secondary)
  }
}

struct TopicListPlaceholderView_Previews: PreviewProvider {
  static var previews: some View {
    TopicListPlaceholderView()
  }
}
