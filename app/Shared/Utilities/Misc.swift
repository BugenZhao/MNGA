//
//  Misc.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI

enum UIIdiom {
  case mac, pad, phone, other
}

func uiIdiom() -> UIIdiom {
  #if os(iOS)
    switch UIDevice.current.userInterfaceIdiom {
    case .mac:
      return .mac
    case .pad:
      return .pad
    case .phone:
      return .phone
    default:
      return .other
    }
  #elseif os(macOS)
    return .mac
  #else
    return .other
  #endif
}
