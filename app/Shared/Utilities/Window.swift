//
//  Window.swift
//  MNGA
//
//  Created by Bugen Zhao on 2022/5/18.
//

import Foundation

#if canImport(UIKit)
  import UIKit

  final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
      AppInterfaceOrientation.supportedOrientations
    }
  }

  enum AppInterfaceOrientation {
    static var supportedOrientations: UIInterfaceOrientationMask {
      guard UIDevice.current.userInterfaceIdiom == .phone else {
        return .allButUpsideDown
      }
      return UserDefaults.standard.bool(forKey: alwaysPortraitOnPhonePreferenceKey) ? .portrait : .allButUpsideDown
    }

    @MainActor
    static func applyCurrentPreference() {
      guard UIDevice.current.userInterfaceIdiom == .phone else { return }

      guard let windowScene = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .first
      else { return }

      windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()

      let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: supportedOrientations)
      windowScene.requestGeometryUpdate(geometryPreferences) { error in
        logger.warning("failed to update interface orientation: \(error.localizedDescription)")
      }
    }
  }

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
