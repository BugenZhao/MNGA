//
//  NavigationPlaceholders.swift
//  NGA
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI

struct TopicListPlaceholderView: View {
  var body: some View {
    PlaceholderView(icon: "list.bullet.rectangle", title: "Select a Forum in Sidebar")
  }
}

struct TopicDetailsPlaceholderView: View {
  var body: some View {
    PlaceholderView(icon: "doc.richtext", title: "Select a Topic")
  }
}
