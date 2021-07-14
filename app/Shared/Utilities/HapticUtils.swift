//
//  HapticUtils.swift
//  NGA
//
//  Created by Bugen Zhao on 7/14/21.
//

import Foundation
import UIKit

struct HapticUtils {
  static let generator = UINotificationFeedbackGenerator()

  static func play(type: UINotificationFeedbackGenerator.FeedbackType) {
    generator.notificationOccurred(type)
  }
}
