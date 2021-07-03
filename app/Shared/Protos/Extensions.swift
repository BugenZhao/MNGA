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

extension Forum {
  var idDescription: String {
    switch self.id! {
    case .fid(let fid): return "#\(fid)"
    case .stid(let stid): return "##\(stid)"
    }
  }
}
