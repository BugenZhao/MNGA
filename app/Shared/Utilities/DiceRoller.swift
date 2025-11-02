//
//  DiceRoller.swift
//  MNGA
//
//  Created by Codex on 2/11/25.
//

import Foundation

enum DiceRoller {
  final class Context {
    private(set) var authorId: Int
    private(set) var topicId: Int
    private(set) var postId: Int
    var seedOffset: Int
    var rndSeed: Int?

    init(authorId: Int, topicId: Int, postId: Int, seedOffset: Int = 0, rndSeed: Int? = nil) {
      self.authorId = authorId
      self.topicId = topicId
      self.postId = postId
      self.seedOffset = seedOffset
      self.rndSeed = rndSeed
    }

    convenience init?(authorIdString: String?, topicIdString: String?, postIdString: String?) {
      guard let authorIdString, let authorId = Int(from: authorIdString),
            let topicIdString, let topicId = Int(from: topicIdString),
            let postIdString, let postId = Int(from: postIdString)
      else {
        return nil
      }
      self.init(authorId: authorId, topicId: topicId, postId: postId)
    }

    func copy(withSeedOffset offset: Int? = nil) -> Context {
      let copy = Context(authorId: authorId, topicId: topicId, postId: postId, seedOffset: offset ?? seedOffset, rndSeed: rndSeed)
      return copy
    }

    private func ensureSeed() -> Int {
      if let seed = rndSeed, seed != 0 {
        return seed
      }

      var seed = authorId + topicId + postId
      if topicId > 10_246_184 || postId > 200_188_932 {
        seed += seedOffset
      }
      if seed == 0 {
        seed = Int.random(in: 0 ..< 10000)
      }
      rndSeed = seed
      return seed
    }

    private func nextSeed() -> Int {
      let current = ensureSeed()
      let next = (current * 9301 + 49297) % 233_280
      rndSeed = next
      return next
    }

    func nextRoll(faces: Int) -> Int {
      precondition(faces > 0, "faces must be positive")
      let seed = nextSeed()
      return (seed * faces) / 233_280 + 1
    }
  }

  struct Result {
    let originalExpression: String
    let expandedExpression: String
    let totalDescription: String
  }

  private enum Sum {
    case number(Int)
    case error

    mutating func add(_ value: Int) {
      switch self {
      case let .number(current):
        self = .number(current + value)
      case .error:
        break
      }
    }

    mutating func setError() {
      self = .error
    }

    func rendered() -> String {
      switch self {
      case let .number(value):
        String(value)
      case .error:
        "ERROR"
      }
    }
  }

  static func roll(expression: String, context: Context) -> Result {
    let original = expression
    if original.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      return Result(originalExpression: original, expandedExpression: "", totalDescription: "ERROR")
    }

    let regex = try! NSRegularExpression(pattern: #"(\+)(\d{0,10})(?:(d)(\d{1,10}))?"#, options: [.caseInsensitive])
    let working = "+" + original
    let matches = regex.matches(in: working, options: [], range: NSRange(working.startIndex..., in: working))

    var output = ""
    var cursor = working.startIndex
    var sum: Sum = .number(0)

    for match in matches {
      guard let range = Range(match.range, in: working) else { continue }
      output.append(contentsOf: working[cursor ..< range.lowerBound])

      let digitsRange = Range(match.range(at: 2), in: working)
      let digitsToken = digitsRange.map { String(working[$0]) } ?? ""
      let hasDice = match.range(at: 3).location != NSNotFound
      let facesRange = Range(match.range(at: 4), in: working)
      let facesToken = facesRange.map { String(working[$0]) } ?? ""

      let diceCount: Int = {
        if let value = Int(digitsToken) {
          return value
        }
        return hasDice ? 1 : 0
      }()

      if !hasDice {
        let value = diceCount
        output.append("+\(value)")
        sum.add(value)
      } else {
        guard let faces = Int(facesToken, radix: 10), faces > 0 else {
          sum.setError()
          output.append("+INVALID")
          cursor = range.upperBound
          continue
        }

        if diceCount > 10 || faces > 100_000 {
          sum.setError()
          output.append("+OUT OF LIMIT")
        } else {
          var replacement = ""
          for _ in 0 ..< diceCount {
            let rollValue = context.nextRoll(faces: faces)
            replacement.append("+d\(facesToken)(\(rollValue))")
            sum.add(rollValue)
          }
          output.append(replacement)
        }
      }

      cursor = range.upperBound
    }

    output.append(contentsOf: working[cursor ..< working.endIndex])

    let expanded = if !output.isEmpty {
      String(output.dropFirst())
    } else {
      ""
    }

    return Result(
      originalExpression: original,
      expandedExpression: expanded,
      totalDescription: sum.rendered()
    )
  }
}
