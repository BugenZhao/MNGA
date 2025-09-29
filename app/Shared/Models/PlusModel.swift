//
//  PlusModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/09/28.
//

import Foundation
import StoreKit
import SwiftUI

enum UnlockStatus: Codable, Equatable {
  case paid
  case trial(expiration: Date)
  case lite

  var isUnlocked: Bool {
    switch self {
    case .paid: true
    case .trial: trialValid!
    case .lite: false
    }
  }

  var trialValid: Bool? {
    if case let .trial(expiration) = self {
      expiration > Date()
    } else {
      nil
    }
  }

  var isPaid: Bool {
    self == .paid
  }

  var isLiteCanTry: Bool {
    self == .lite
  }

  /// "Try Plus" or "Unlock Plus"
  var tryOrUnlock: LocalizedStringKey {
    isLiteCanTry ? "Try Plus" : "Unlock Plus"
  }
}

class PaywallModel: ObservableObject {
  static let shared = PaywallModel()

  @Published var isShowingModal = false

  @AppStorage("cachedUnlockStatus") var cachedStatusData: Data = .init()
  var cachedStatus: UnlockStatus {
    get {
      (try? JSONDecoder().decode(UnlockStatus.self, from: cachedStatusData)) ?? .lite
    }
    set {
      cachedStatusData = (try? JSONEncoder().encode(newValue)) ?? Data()
    }
  }

  @Published var isOnlineStatus: Bool = false

  var onlineStatus: UnlockStatus? {
    isOnlineStatus ? cachedStatus : nil
  }

  var isUnlocked: Bool {
    cachedStatus.isUnlocked
  }

  init() {
    Task.detached { await self.listenForTransactions() }
  }

  private func listenForTransactions() async {
    await updateStatus()

    for await result in Transaction.updates {
      logger.info("transaction update: \(result)")
      if case let .verified(txn) = result {
        await txn.finish()
      }
      await updateStatus()
    }
  }

  func updateStatus() async {
    let status = await fetchStatus()

    await MainActor.run {
      cachedStatus = status
      isOnlineStatus = true
    }
  }

  func fetchStatus() async -> UnlockStatus {
    if case let .verified(txn) = await Transaction.latest(for: Constants.Plus.unlockID),
       txn.revocationDate == nil
    {
      logger.info("found unlocked transaction: \(txn)")
      return UnlockStatus.paid
    } else if case let .verified(txn) = await Transaction.latest(for: Constants.Plus.trialID),
              txn.revocationDate == nil
    {
      logger.info("found trial transaction: \(txn)")
      let exp = Calendar.current.date(byAdding: .day, value: 14, to: txn.purchaseDate) ?? Date()
      return UnlockStatus.trial(expiration: exp)
    } else {
      logger.info("no valid transaction found")
      return UnlockStatus.lite
    }
  }
}

func checkPlus() -> Bool {
  withPlusCheck { () } != nil
}

func withPlusCheck<Result>(_ body: () throws -> Result) rethrows -> Result? {
  let paywall = PaywallModel.shared

  if paywall.isUnlocked {
    return try body()
  } else {
    ToastModel.showAuto(.requirePlus)
    return nil
  }
}

struct PlusCheckNavigationLink<Label, Destination>: View where Label: View, Destination: View {
  @EnvironmentObject var paywall: PaywallModel

  let destination: Destination
  let isDetailLink: Bool?
  let label: Label

  init(
    destination: Destination,
    isDetailLink: Bool? = nil,
    @ViewBuilder label: () -> Label
  ) {
    self.destination = destination
    self.isDetailLink = isDetailLink
    self.label = label()
  }

  var body: some View {
    if paywall.isUnlocked {
      NavigationLink(destination: destination, label: { label })
        .if(isDetailLink != nil) { $0.isDetailLink(isDetailLink!) }
    } else {
      Button(action: { ToastModel.showAuto(.requirePlus) }, label: { label })
    }
  }
}
