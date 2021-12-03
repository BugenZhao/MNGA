//
//  PlaceholderView.swift
//  PlaceholderView
//
//  Created by Bugen Zhao on 7/19/21.
//

import Foundation
import SwiftUI

struct PlaceholderView: View {
  let icon: String?
  let title: LocalizedStringKey

  var body: some View {
    VStack(spacing: 12) {
      if let icon = icon {
        Image(systemName: icon)
          .font(.largeTitle)
      }
      Text(title)
        .font(.callout)
    }.foregroundColor(.secondary)
  }
}
