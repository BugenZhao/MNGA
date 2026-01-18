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
    ContentUnavailableView("Select a Forum in Sidebar", systemImage: "list.bullet.rectangle")
  }
}

struct TopicDetailsPlaceholderView: View {
  var body: some View {
    ContentUnavailableView("Select a Topic", systemImage: "doc.richtext")
      .toolbar {
        NotificationToolbarItem(placement: .navigationBarTrailing)
      }
  }
}
