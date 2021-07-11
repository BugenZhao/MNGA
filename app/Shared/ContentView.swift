//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI
import SwiftUIX

struct ContentView: View {
  @StateObject var viewingImage = ViewingImageModel()

  var body: some View {
    Group {
      if UserInterfaceIdiom.current == .pad {
        NavigationView {
          ForumListView()
          TopicListPlaceholderView()
          EmptyView()
        }
      } else {
        NavigationView {
          ForumListView()
        }
      }
    } .overlay { ImageOverlay() }
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
