//
//  ZoomableScrollView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/3.
//

import Foundation
import SwiftUI

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
  private let content: Content
  private let scale: Binding<CGFloat>

  init(scale: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
    self.content = content()
    self.scale = scale
  }

  func makeUIView(context: Context) -> UIScrollView {
    // set up the UIScrollView
    let scrollView = UIScrollView()
    scrollView.delegate = context.coordinator // for viewForZooming(in:)
    scrollView.maximumZoomScale = 20
    scrollView.minimumZoomScale = 1
    scrollView.bouncesZoom = true
    scrollView.showsVerticalScrollIndicator = false
    scrollView.showsHorizontalScrollIndicator = false

    // create a UIHostingController to hold our SwiftUI content
    if let hostedView = context.coordinator.hostingController.view {
      hostedView.translatesAutoresizingMaskIntoConstraints = true
      hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      hostedView.frame = scrollView.bounds
      hostedView.backgroundColor = .clear
      scrollView.addSubview(hostedView)
    }

    return scrollView
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  func updateUIView(_: UIScrollView, context _: Context) {
    // update the hosting controller's SwiftUI content
//    context.coordinator.hostingController.rootView = self.content
//    assert(context.coordinator.hostingController.view.superview == uiView)
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, UIScrollViewDelegate {
    let hostingController: UIHostingController<Content>
    let parent: ZoomableScrollView

    init(parent: ZoomableScrollView) {
      hostingController = UIHostingController(rootView: parent.content)
      self.parent = parent
    }

    func viewForZooming(in _: UIScrollView) -> UIView? {
      hostingController.view
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      parent.scale.wrappedValue = scrollView.zoomScale
    }
  }
}
