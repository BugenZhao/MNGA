//
//  PlusView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/09/28.
//

import Foundation
import StoreKit
import SwiftUI

struct PlusView: View {
  @EnvironmentObject var paywall: PaywallModel

  var body: some View {
    Group {
      if let current = paywall.onlineStatus {
        switch current {
        case .paid:
          Text("Plus Unlocked").font(.headline)
        case .trial:
          StoreView(ids: [Constants.Plus.unlockID])
            .storeButton(.visible, for: .restorePurchases)
        case .lite:
          StoreView(ids: [Constants.Plus.unlockID, Constants.Plus.trialID])
            .storeButton(.visible, for: .restorePurchases)
        }
      } else {
        ProgressView()
      }
    }.navigationTitleInline(key: "Unlock Plus")
  }
}

struct PlusSheetView: View {
  var body: some View {
    NavigationStack {
      PlusView()
    }
  }
}
