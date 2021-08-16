//
//  VotesModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation
import Combine
import SwiftUI

class VotesModel: ObservableObject {
  typealias Vote = (state: VoteState, delta: Int32)
  @Published private var votes = [PostId: Vote]()

  func binding(for post: Post) -> Binding<Vote> {
    return Binding(
      get: {
        return self.votes[post.id] ?? (state: post.voteState, delta: 0)
      },
      set: {
        self.votes[post.id] = $0
      }
    )
  }
}

