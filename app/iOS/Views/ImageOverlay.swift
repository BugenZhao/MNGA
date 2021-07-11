//
//  ImageOverlay.swift
//  NGA (iOS)
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI
import SwiftUIX
import ImageViewer

struct ImageOverlay: View {
  @EnvironmentObject var model: ViewingImageModel

  @State var showingShare = false

  var body: some View {
    ZStack {
      ImageViewer(
        image: $model.imageView,
        viewerShown: $model.isShowing
      )

      if (model.isShowing) {
        VStack {
          HStack(alignment: .center) {
            Spacer()
            Button(action: { self.showingShare = true }) {
              Image(systemName: "ellipsis")
                .foregroundColor(.white)
                .font(.system(size: UIFontMetrics.default.scaledValue(for: 24)))
            }
          } .frame(height: UIFontMetrics.default.scaledValue(for: 24))

          Spacer()
        } .padding()
          .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
      }

    } .sheet(isPresented: $showingShare, content: {
      AppActivityView(activityItems: [model.image as Any])
    })
  }
}
