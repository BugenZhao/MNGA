//
//  AdaptiveFooterView.swift
//  NGA
//
//  Created by Bugen Zhao on 1/18/26.
//

import Foundation
import SwiftUI

// An adaptive footer view that adapts to different screen sizes.
// - If there's enough space, `leading` and `trailing` are put in a single line.
// - Otherwise, `leading` and `trailing` are put in two lines, where `trailing` is aligned to the trailing edge.
struct AdaptiveFooterView<Leading: View, Trailing: View>: View {
  let leading: () -> Leading
  let trailing: () -> Trailing

  init(
    @ViewBuilder leading: @escaping () -> Leading,
    @ViewBuilder trailing: @escaping () -> Trailing,
  ) {
    self.leading = leading
    self.trailing = trailing
  }

  var body: some View {
    ViewThatFits {
      HStack(alignment: .center) {
        leading().layoutPriority(1)
        Spacer()
        trailing()
      }

      VStack(alignment: .leading) {
        HStack(alignment: .center) {
          leading()
        }
        HStack(alignment: .center) {
          trailing()
        }.frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }
}
