//
//  Logger.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Foundation
import Logging

let logger = Logger.withDefaultLevel(label: "App")

extension Logger {
  static func withDefaultLevel(label: String) -> Logger {
    var logger = Logger(label: label)
    #if DEBUG
      logger.logLevel = .debug
    #else
      logger.logLevel = .info
    #endif
    return logger
  }
}
