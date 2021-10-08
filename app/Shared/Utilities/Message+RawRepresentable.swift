//
//  Array+RawRepresentable.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import SwiftProtobuf

extension Array: RawRepresentable where Element: SwiftProtobuf.Message {
  public init?(rawValue: String) {
    guard let data = rawValue.data(using: .utf8),
      let strings = try? JSONDecoder().decode([String].self, from: data)
      else {
      return nil
    }
    let result = strings.compactMap { s in
      try? Element.init(jsonString: s)
    }
    self = result
  }

  public var rawValue: String {
    let strings = self.compactMap { e in
      try? e.jsonString()
    }
    guard let data = try? JSONEncoder().encode(strings),
      let result = String(data: data, encoding: .utf8)
      else {
      return "[]"
    }
    return result
  }
}

public struct WrappedMessage<M> where M: SwiftProtobuf.Message {
  public var inner: M
}

extension WrappedMessage: RawRepresentable {
  public init?(rawValue: String) {
    guard let result = try? M.init(jsonString: rawValue)
      else {
      return nil
    }
    self.inner = result
  }

  public var rawValue: String {
    guard let result = try? self.inner.jsonString()
      else {
      return "{}"
    }
    return result
  }
}

extension WrappedMessage: Equatable {

}

extension RawRepresentable where RawValue == String {
  init?(readFrom userDefaults: UserDefaults, forKey defaultName: String) {
    let string = userDefaults.string(forKey: defaultName) ?? ""
    self.init(rawValue: string)
  }
}
