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
      return (.subheadline.weight(.regular), .accentColor.opacity(0.0))
    case 1 ..< 40:
      return (.callout.weight(.medium), .accentColor.opacity(0.8))
    case 40 ..< 100:
      return (.callout.weight(.semibold), .accentColor.opacity(0.9))
    case 100 ..< 200:
      return (.body.weight(.semibold), .accentColor)
    case 200 ..< 500:
      return (.body.weight(.bold), .accentColor)
    case 500...:
      return (.body.weight(.heavy), .accentColor)
    default:
      return (nil, nil)
    }
  }

  var text: some View {
    let (font, color) = fontStyle
    var text = Text("\(num)").font(font)
    if let lastNum = lastNum, num > lastNum {
      text = text + Text("(+\(num - lastNum))").font(.footnote)
    }
    return text.foregroundColor(color)
  }

  var body: some View {
    text
  }
}
