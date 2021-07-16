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
  @EnvironmentObject var activity: ActivityModel

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
            Button(action: { self.activity.put(model.image) }) {
              Image(systemName: "square.and.arrow.up")
                .foregroundColor(.white)
                .font(.system(size: UIFontMetrics.default.scaledValue(for: 24)))
            }
          } .frame(height: UIFontMetrics.default.scaledValue(for: 24))

          Spacer()
        } .padding()
          .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
          .zIndex(233)
      }
    }
  }
}
