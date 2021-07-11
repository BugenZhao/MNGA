//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI
import ImageViewer
import SwiftUIX

struct ContentView: View {
  @StateObject var viewingImage = ViewingImageModel()

  var body: some View {
    NavigationView {
      ForumListView()
      if UserInterfaceIdiom.current == .pad {
        TopicListPlaceholderView()
      }
      if UserInterfaceIdiom.current == .pad {
        EmptyView()
      }
    }
      .overlay { ImageOverlay() }
      .environmentObject(viewingImage)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
    }
  }
}
