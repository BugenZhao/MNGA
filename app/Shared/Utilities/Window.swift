//
//  Window.swift
//  MNGA
//
//  Created by Bugen Zhao on 2022/5/18.
//

import Foundation

#if canImport(UIKit)
  import UIKit

  extension UIApplication {
    static var myKeyWindow: UIWindow? {
      // Get connected scenes
      UIApplication.shared.connectedScenes
        // Keep only the first `UIWindowScene`
        .first(where: { $0 is UIWindowScene })
        // Get its associated windows
        .flatMap { $0 as? UIWindowScene }?.windows
        // Finally, keep only the key window
        .first(where: \.isKeyWindow)
    }
  }
#endif
