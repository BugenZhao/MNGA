//
//  Misc.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import Logging

let logger: Logger = {
  var logger = Logger(label: "App")
  logger.logLevel = .info
  return logger
}();
