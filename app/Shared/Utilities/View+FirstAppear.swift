//
//  View+FirstAppear.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import SwiftUI

extension View {
  /// Fix the SwiftUI bug for onAppear twice in subviews
  /// - Parameters:
  ///   - perform: perform the action when appear
  @available(*, deprecated, message: "nope")
  func onFirstAppear(perform: @escaping () -> Void) -> some View {
    let kAppearAction = "appear_action"
    let queue = OperationQueue.main
    let delayOperation = BlockOperation {
      Thread.sleep(forTimeInterval: 0.001)
    }
    let appearOperation = BlockOperation {
      perform()
    }
    appearOperation.name = kAppearAction
    appearOperation.addDependency(delayOperation)
    return onAppear {
      if !delayOperation.isFinished, !delayOperation.isExecuting {
        queue.addOperation(delayOperation)
      }
      if !appearOperation.isFinished, !appearOperation.isExecuting {
        queue.addOperation(appearOperation)
      }
    }
    .onDisappear {
      queue.operations
        .first { $0.name == kAppearAction }?
        .cancel()
    }
  }
}
