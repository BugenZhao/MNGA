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
  logger.logLevel = .info
  return logger
}()
