//
//  HapticUtils.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import UIKit

struct HapticUtils {
  static let notification = UINotificationFeedbackGenerator()

  static func play(type: UINotificationFeedbackGenerator.FeedbackType) {
    notification.notificationOccurred(type)
  }

  static func play(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
  }
}
