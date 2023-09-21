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
    case .leading: .leading
    case .center: .center
    case .trailing: .trailing
    default: .leading
    }
  }
}
