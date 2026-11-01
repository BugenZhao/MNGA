//
//  NavigationPlaceholders.swift
//  NGA
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct TopicListPlaceholderView: View {
  @EnvironmentObject.Optional var columnVisibility: ColumnVisibility?

  var body: some View {
    ContentUnavailableView("Select a Forum in Sidebar", systemImage: "list.bullet.rectangle")
      .onAppear { columnVisibility?.isContentColumnEmpty = true }
      .onDisappear { columnVisibility?.isContentColumnEmpty = false }
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
