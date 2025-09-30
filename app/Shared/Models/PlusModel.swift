//
//  PlusModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/09/28.
//

import Foundation
import StoreKit
import SwiftUI

enum PlusFeature {
  case postOrReply
  case hotTopic
  case shortMessage
  case topicHistory
  case notification
  case authorOnly
  case jump
  case multiAccount
  case userProfile

  var description: String {
    switch self {
    case .postOrReply:
      "Post/Reply"
    case .hotTopic:
      "Hot Topics"
    case .shortMessage:
      "Short Messages"
    case .topicHistory:
      "History"
    case .notification:
      "Notifications"
    case .authorOnly:
      "Author Only"
    case .jump:
      "Jump"
    case .multiAccount:
      "Multiple Accounts"
    case .userProfile:
      "User Profile"
    }
  }
}

// Note the order of all cases for `Comparable`!
enum UnlockStatus: Codable, Equatable, Comparable {
  case lite
  case trial(expiration: Date)
  case paid

  var isUnlocked: Bool {
    switch self {
    case .paid: true
    case .trial: trialValid ?? false
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

  /// Whether we should present a prominent button to unlock.
  var shouldUseProminent: Bool {
    switch self {
      case .lite: true // try now!!
      case .trial: !(trialValid ?? false) // expired
      case .paid: false
    }
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
      if !isOnlineStatus, cachedStatus != status {
        logger.warning("mismatch between cached and online status: \(cachedStatus) vs \(status)")
      }
      cachedStatus = status
      isOnlineStatus = true
    }
  }

  func fetchStatus() async -> UnlockStatus {
    var status = UnlockStatus.lite

    for await entitlement in Transaction.currentEntitlements {
      if let txn = try? entitlement.payloadValue {
        if txn.productID == Constants.Plus.unlockID {
          logger.info("found unlocked transaction: \(txn)")
          status = max(status, .paid)
        } else if txn.productID == Constants.Plus.trialID {
          logger.info("found trial transaction: \(txn)")
          let exp = Calendar.current.date(byAdding: .day, value: 14, to: txn.purchaseDate) ?? Date()
          status = max(status, .trial(expiration: exp))
        } else {
          logger.info("found unknown transaction: \(txn)")
        }
      }
    }

    if status == .lite {
      logger.info("no valid transaction found")
    }
    return status
  }
}

func checkPlus(_ feature: PlusFeature) -> Bool {
  withPlusCheck(feature) { () } != nil
}

func withPlusCheck<Result>(_ feature: PlusFeature, _ body: () throws -> Result) rethrows -> Result? {
  let paywall = PaywallModel.shared

  if paywall.isUnlocked {
    return try body()
  } else {
    ToastModel.showAuto(.requirePlus(feature))
    return nil
  }
}

struct PlusCheckNavigationLink<Label, Destination>: View where Label: View, Destination: View {
  @EnvironmentObject var paywall: PaywallModel

  let destination: Destination
  let feature: PlusFeature
  let isDetailLink: Bool?
  let label: Label

  init(
    destination: Destination,
    feature: PlusFeature,
    isDetailLink: Bool? = nil,
    @ViewBuilder label: () -> Label
  ) {
    self.destination = destination
    self.feature = feature
    self.isDetailLink = isDetailLink
    self.label = label()
  }

  var body: some View {
    if paywall.isUnlocked {
      NavigationLink(destination: destination, label: { label })
        .if(isDetailLink != nil) { $0.isDetailLink(isDetailLink!) }
    } else {
      Button(action: { ToastModel.showAuto(.requirePlus(feature)) }, label: { label })
    }
  }
}
