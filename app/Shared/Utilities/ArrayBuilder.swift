//
//  ArrayBuilder.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/3.
//

import Foundation

// https://gist.github.com/dreymonde/98d73932efa5441acf55cd2853cdeb91
@resultBuilder
public enum ArrayBuilder<Element> {
  public typealias Expression = Element

  public typealias Component = [Element]

  public static func buildExpression(_ expression: Expression) -> Component {
    [expression]
  }

  public static func buildExpression(_ expression: Expression?) -> Component {
    expression.map({ [$0] }) ?? []
  }

  public static func buildBlock(_ children: Component...) -> Component {
    children.flatMap({ $0 })
  }

  public static func buildOptional(_ children: Component?) -> Component {
    children ?? []
  }

  public static func buildBlock(_ component: Component) -> Component {
    component
  }

  public static func buildEither(first child: Component) -> Component {
    child
  }

  public static func buildEither(second child: Component) -> Component {
    child
  }
}
