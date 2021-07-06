//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI
import ImageViewer

struct ContentView: View {
  @StateObject var viewingImage = ViewingImageModel()

  @ViewBuilder
  var imageOverlay: some View {
    ImageViewer(
      image: $viewingImage.overlayImage,
      viewerShown: $viewingImage.overlayImage.isNotNil()
    )
  }

  var body: some View {
    NavigationView {
      ForumListView()
    }
      .environmentObject(viewingImage)
      .overlay { imageOverlay }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
    }
  }
}
