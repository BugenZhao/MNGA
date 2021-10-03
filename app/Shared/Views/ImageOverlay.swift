//
//  ImageOverlay.swift
//  NGA (iOS)
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI

struct ImageViewer<Content: View>: View {
  @ObservedObject var prefs = PreferencesStorage.shared
  
  @Binding var view: Content?

  @State var scale: CGFloat = 1.0
  @State var dragOffset: CGSize = CGSize.zero

  var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in self.dragOffset = value.translation }
      .onEnded { value in
      let offset = value.translation
      let predicted = value.predictedEndTranslation
      if abs(offset.height) + abs(offset.width) > 570 ||
        abs(predicted.height) / abs(offset.height) > 3 ||
        abs(predicted.width) / abs(offset.width) > 3
      {
        withAnimation(.spring()) { self.dragOffset = predicted }
        self.view = nil
      } else {
        withAnimation(.interactiveSpring()) { self.dragOffset = .zero }
      }
    }
  }

  @ViewBuilder
  public var body: some View {
    if let view = view {
      Group {
        if prefs.imageViewerEnableZoom {
          ZoomableScrollView(scale: $scale) {
            view.aspectRatio(contentMode: .fit)
          }
        } else {
          view.aspectRatio(contentMode: .fit)
        }
      }
        .edgesIgnoringSafeArea(.all)
        .offset(x: self.dragOffset.width, y: self.dragOffset.height)
        .rotationEffect(.init(degrees: Double(self.dragOffset.width / 30)))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.12, green: 0.12, blue: 0.12, opacity: (1.0 - Double(abs(self.dragOffset.width) + abs(self.dragOffset.height)) / 1000)).edgesIgnoringSafeArea(.all))
        .zIndex(1)
        .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.2)))
//        .onAppear { self.dragOffset = .zero; self.scale = 1.0 }
        .onChange(of: scale) { s in if s != 1.0 { self.dragOffset = .zero } }
        .gesture(self.scale == 1.0 ? dragGesture : nil)
    }
  }
}

struct ImageOverlay: View {
  @EnvironmentObject var model: ViewingImageModel
  @EnvironmentObject var activity: ActivityModel

  var body: some View {
    ImageViewer(view: $model.view)
      .overlay(alignment: .topTrailing) {
      if model.view != nil && model.imageData != nil {
        Button(action: { self.activity.put(model.imageData) }) {
          Image(systemName: "square.and.arrow.up")
            .padding(.small)
            .foregroundColor(.white)
            .background(.white.opacity(0.35))
            .clipShape(Circle())
        } .padding(10)
      }
    }
      .id(model.id)
  }
}
