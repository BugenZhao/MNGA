//
//  PostReplyRelationScanner.swift
//  MNGA
//
//  Created by Codex on 2026/2/10.
//

import Foundation

enum PostReplyRelationScanner {
  static func target(in content: PostContent) -> PostId? {
    target(in: content.spans)
  }

  private static func target(in spans: some Sequence<Span>) -> PostId? {
    // Backend contract guarantees a single quote relation per post.
    // Keep only one target so index/update logic stays simple and deterministic.
    var latest: PostId?

    for span in spans {
      guard let value = span.value, case let .tagged(tagged) = value else { continue }

      switch tagged.tag {
      case "quote":
        let metaSpans = tagged.spans.prefix { $0.value != .breakLine(.init()) }
        if let meta = extractMeta(from: metaSpans) {
          latest = meta
          let contentSpans = tagged.spans.dropFirst(metaSpans.count)
          if let nested = target(in: contentSpans) {
            latest = nested
          }
        } else {
          if let nested = target(in: tagged.spans) {
            latest = nested
          }
        }
      case "b":
        if tagged.spans.first?.plain.text.starts(with: "Reply to") == true {
          let metaSpans = tagged.spans.dropFirst()
          if let meta = extractMeta(from: metaSpans) {
            latest = meta
            continue
          }
        }
        if let nested = target(in: tagged.spans) {
          latest = nested
        }
      default:
        if let nested = target(in: tagged.spans) {
          latest = nested
        }
      }
    }

    return latest
  }

  private static func extractMeta(from spans: some Sequence<Span>) -> PostId? {
    let extractor = MetaExtractor()
    extractor.visit(spans: spans)
    guard extractor.uid != nil else { return nil }
    return extractor.replyTo
  }
}

private final class MetaExtractor {
  private(set) var replyTo: PostId?
  private(set) var uid: String?

  func visit(spans: some Sequence<Span>) {
    for span in spans {
      visit(span: span)
    }
  }

  private func visit(span: Span) {
    guard let value = span.value, case let .tagged(tagged) = value else { return }

    switch tagged.tag {
    case "uid":
      if let first = tagged.attributes.first {
        uid = first
      } else if let name = tagged.spans.first?.plain.text, !name.isEmpty {
        uid = name
      }
      visit(spans: tagged.spans)
    case "pid":
      if tagged.attributes.count > 2 {
        replyTo = .with {
          $0.pid = tagged.attributes[0]
          $0.tid = tagged.attributes[1]
        }
      }
      visit(spans: tagged.spans)
    case "tid":
      if let tid = tagged.attributes.first {
        replyTo = .with {
          $0.pid = "0"
          $0.tid = tid
        }
      }
      visit(spans: tagged.spans)
    default:
      visit(spans: tagged.spans)
    }
  }
}
