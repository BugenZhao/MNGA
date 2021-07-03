//
//  Extensions.swift
//  NGA
//
//  Created by Bugen Zhao on 7/3/21.
//

import Foundation

extension Topic {
  var subjectFull: String {
    self.tags.map { t in "[\(t)] " }.joined() + self.subjectContent
  }
}
