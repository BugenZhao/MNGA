//
//  VotesModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Combine
import Foundation
import SwiftUI

class VotesModel: ObservableObject {
  typealias Vote = (state: VoteState, delta: Int32)

  // TODO: check performance cost here
  @Published private var votes = [PostId: Vote]()

  func binding(for post: Post) -> Binding<Vote> {
    Binding(
      get: {
        self.votes[post.id] ?? (state: post.voteState, delta: 0)
      },
      set: {
        self.votes[post.id] = $0
      },
    )
  }
}
