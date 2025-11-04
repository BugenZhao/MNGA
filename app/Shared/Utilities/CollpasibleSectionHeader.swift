//
//  CollpasibleSectionHeader.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/11/04.
//

import SwiftUI

struct CollapsibleSectionHeader: View {
  let title: LocalizedStringKey
  @Binding var isExpanded: Bool

  var body: some View {
    HStack {
      Text(title)
      Spacer()
      Image(systemName: "chevron.right")
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
    }
    .contentShape(.rect)
    .onTapGesture { withAnimation { isExpanded.toggle() } }
  }
}
