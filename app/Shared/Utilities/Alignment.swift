//
//  Alignment.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/22.
//

import Foundation
import SwiftUI

extension HorizontalAlignment {
  var textAlignment: TextAlignment {
    switch self {
    case .leading: return .leading
    case .center: return .center
    case .trailing: return .trailing
    default: return .leading
    }
  }
}
