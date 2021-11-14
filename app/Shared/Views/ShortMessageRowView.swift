//
//  ShortMessageRowView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/16.
//

import Foundation
import SwiftUI

struct ShortMessageRowView: View {
  let message: ShortMessage

  @ViewBuilder
  var subjectView: some View {
    TopicSubjectContentInnerView(content: message.subject, lineLimit: nil)
  }

  var body: some View {
    TopicLikeRowInnerView(subjectView: { subjectView }, num: message.postNum, lastNum: nil, name: .with { $0.normal = message.fromName }, date: message.lastPostDate)
  }
}
