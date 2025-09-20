//
//  Logger.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Foundation
import Logging

let logger: Logger = {
  var logger = Logger(label: "App")
  #if DEBUG
    logger.logLevel = .debug
  #else
    logger.logLevel = .info
  #endif
  return logger
}()
