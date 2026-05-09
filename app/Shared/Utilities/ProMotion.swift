//
//  ProMotion.swift
//  MNGA
//
//  Created by Bugen Zhao on 2026/5/9.
//

import Foundation
import QuartzCore
import UIKit

final class ProMotionDisplayLink: NSObject {
  static let shared = ProMotionDisplayLink()

  private var displayLink: CADisplayLink?

  func setEnabled(_ enabled: Bool) {
    if enabled {
      start()
    } else {
      stop()
    }
  }

  func start() {
    guard displayLink == nil else { return }

    let targetFPS = Float(min(UIScreen.main.maximumFramesPerSecond, 120))
    let link = CADisplayLink(target: self, selector: #selector(tick))
    link.preferredFrameRateRange = CAFrameRateRange(
      minimum: targetFPS,
      maximum: targetFPS,
      preferred: targetFPS,
    )
    link.add(to: .main, forMode: .common)
    displayLink = link

    logger.info("started ProMotion display link at \(targetFPS) FPS")
  }

  func stop() {
    guard let displayLink else { return }
    displayLink.invalidate()
    self.displayLink = nil

    logger.info("stopped ProMotion display link")
  }

  @objc private func tick(_: CADisplayLink) {}
}
