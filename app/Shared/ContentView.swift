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
  @StateObject var activity = ActivityModel()

  var body: some View {
    Group {
      if UserInterfaceIdiom.current == .pad || UserInterfaceIdiom.current == .mac {
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
      .sheet(isPresented: $activity.activityItems.isNotNil(), content: {
        AppActivityView(activityItems: activity.activityItems ?? [])
      })
      .modifier(HudToastModifier())
      .environmentObject(viewingImage)
      .environmentObject(activity)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
    }
  }
}
