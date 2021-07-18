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
    PlaceholderView(icon: "list.bullet.rectangle", title: "Select a forum in sidebar")
  }
}

struct TopicListPlaceholderView_Previews: PreviewProvider {
  static var previews: some View {
    TopicListPlaceholderView()
  }
}
