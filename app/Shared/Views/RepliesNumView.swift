//
//  RepliesNumView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Foundation
import SwiftUI

struct RepliesNumView: View {
  let num: UInt32
  let lastNum: UInt32?

  var fontStyle: (Font?, Color?) {
    switch num {
    case 0:
      (.subheadline.weight(.regular), .accentColor.opacity(0.0))
    case 1 ..< 40:
      (.callout.weight(.medium), .accentColor.opacity(0.8))
    case 40 ..< 100:
      (.callout.weight(.semibold), .accentColor.opacity(0.9))
    case 100 ..< 200:
      (.body.weight(.semibold), .accentColor)
    case 200 ..< 500:
      (.body.weight(.bold), .accentColor)
    case 500...:
      (.body.weight(.heavy), .accentColor)
    default:
      (nil, nil)
    }
  }

  var text: some View {
    let (font, color) = fontStyle
    var text = Text("\(num)").font(font)
    if let lastNum, num > lastNum {
      text = text + Text("(+\(num - lastNum))").font(.footnote)
    }
    return text.foregroundColor(color)
  }

  var body: some View {
    text
  }
}
