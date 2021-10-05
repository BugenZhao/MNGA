//
//  ImageOverlay.swift
//  NGA (macOS)
//
//  Created by Bugen Zhao on 7/11/21.
//

import Foundation
import SwiftUI

struct ImageOverlay: View {
  @EnvironmentObject var model: ViewingImageModel

  var body: some View {
    if let view = model.view {
      view
    }
  }
}
