//
//  ImageOverlay.swift
//  NGA (iOS)
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI
import SwiftUIX

struct ImageOverlay: View {
  @EnvironmentObject var model: ViewingImageModel
  @EnvironmentObject var activity: ActivityModel

  var body: some View {
    ImageViewer(
      view: model.view,
      viewerShown: $model.view.isNotNil().animation()
    ) .overlay(alignment: .topTrailing) {
      if model.view != nil && model.image != nil {
        Button(action: { self.activity.put(model.image) }) {
          Image(systemName: "square.and.arrow.up")
            .padding(.small)
            .foregroundColor(.white)
            .background(.white.opacity(0.35))
            .clipShape(Circle())
        } .padding(10)
      }
    }
  }
}
