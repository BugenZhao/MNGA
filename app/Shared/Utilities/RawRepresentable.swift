//
//  RawRepresentable.swift
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

extension Set: RawRepresentable where Element: SwiftProtobuf.Message {
  public init?(rawValue: String) {
    if let array = [Element].init(rawValue: rawValue) {
      self = Set(array)
    } else {
      return nil
    }
  }

  public var rawValue: String {
    return Array(self).rawValue
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

extension Optional: RawRepresentable where Wrapped: RawRepresentable, Wrapped.RawValue == String {
  public var rawValue: String {
    if let s = self {
      return s.rawValue
    } else {
      return "<nil>"
    }
  }

  public init?(rawValue: String) {
    if rawValue == "<nil>" {
      return nil
    } else {
      self = Wrapped(rawValue: rawValue)
    }
  }
}

extension AuthInfo: RawRepresentable {
  public init?(rawValue: String) {
    if let w = WrappedMessage<AuthInfo>(rawValue: rawValue) {
      self = w.inner
    } else {
      return nil
    }
  }

  public var rawValue: String {
    WrappedMessage(inner: self).rawValue
  }
}
