//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI
import SwiftUIX
import AlertToast

struct ContentView: View {
  @StateObject var viewingImage = ViewingImageModel()
  @StateObject var toast = ToastModel.shared

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
      .toast(isPresenting: $toast.message.isNotNil(), duration: 3, tapToDismiss: true) {
      AlertToast(displayMode: .hud, type: .error(.red), title: NSLocalizedString("Error", comment: ""), subTitle: toast.message)
    }
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
