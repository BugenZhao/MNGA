//
//  PlusModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/09/28.
//

import Foundation
import StoreKit
import SwiftUI

// Note the order of all cases for `Comparable`!
enum UnlockStatus: Codable, Equatable, Comparable, Hashable {
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

  /// All cases for debugging purposes.
  static let debugAllCases: [UnlockStatus?] = [
    nil,
    .lite,
    .trial(expiration: Date(timeIntervalSince1970: 0)),
    .trial(expiration: Date(timeIntervalSinceNow: 60 * 60 * 24 * 14)),
    .paid,
  ]
}

class PaywallModel: ObservableObject {
  static let shared = PaywallModel()

  @Published var isShowingModal = false

  @AppStorage("cachedUnlockStatus") var cachedStatusData = Data()
  private var cachedStatus: UnlockStatus {
    get {
      (try? JSONDecoder().decode(UnlockStatus.self, from: cachedStatusData)) ?? .lite
    }
    set {
      cachedStatusData = (try? JSONEncoder().encode(newValue)) ?? Data()
    }
  }

  @Published var debugOverride: UnlockStatus? = nil

  var status: UnlockStatus {
    #if DEBUG
      debugOverride ?? cachedStatus
    #else
      cachedStatus
    #endif
  }

  @Published var isStatusTrusted = false

  var trustedStatus: UnlockStatus? {
    isStatusTrusted ? status : nil
  }

  var isUnlocked: Bool {
    status.isUnlocked
  }

  init() {
    Task.detached { await self.listenForTransactions() }
  }

  private func listenForTransactions() async {
    await updateStatus(initial: true)

    for await result in Transaction.updates {
      logger.info("transaction update: \(result)")
      if case let .verified(txn) = result {
        await txn.finish()
      }
      await updateStatus()
    }
  }

  // If `initial` is true, we will only update the cached status and set `isStatusTrusted`
  // if the new status is more powerful.
  func updateStatus(initial: Bool = false) async {
    let newStatus = await fetchStatus()

    await MainActor.run {
      if initial {
        if cachedStatus != newStatus {
          logger.warning("mismatch between cached and new status while initializing: \(cachedStatus) vs \(newStatus)")
        }
        isStatusTrusted = newStatus >= cachedStatus
        cachedStatus = max(cachedStatus, newStatus)
      } else {
        isStatusTrusted = true
        cachedStatus = newStatus
      }
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

extension Binding where Value: Equatable {
  func withPlusCheck(_ feature: PlusFeature) -> Self {
    Binding(
      get: { self.wrappedValue },
      set: { newValue in
        if newValue == self.wrappedValue { return }
        MNGA.withPlusCheck(feature) { self.wrappedValue = newValue }
      },
    )
  }
}

struct PlusCheckNavigationLink<Label, Destination>: View where Label: View, Destination: View {
  @EnvironmentObject var paywall: PaywallModel

  let destination: Destination
  let feature: PlusFeature
  let isDetailLink: Bool
  let label: Label

  init(
    destination: Destination,
    feature: PlusFeature,
    isDetailLink: Bool = true,
    @ViewBuilder label: () -> Label,
  ) {
    self.destination = destination
    self.feature = feature
    self.isDetailLink = isDetailLink
    self.label = label()
  }

  var body: some View {
    if paywall.isUnlocked {
      NavigationLink(destination: destination, label: { label })
        .isDetailLink(isDetailLink)
    } else {
      Button(action: { ToastModel.showAuto(.requirePlus(feature)) }, label: { label })
    }
  }
}

struct DisableWithPlusCheckModifier: ViewModifier {
  @EnvironmentObject var paywall: PaywallModel

  let feature: PlusFeature

  func body(content: Content) -> some View {
    if paywall.isUnlocked {
      content
    } else {
      content
        .disabled(true)
        .contentShape(.rect) // for tap gesture
        .onTapGesture { ToastModel.showAuto(.requirePlus(feature)) }
    }
  }
}

extension View {
  func disableWithPlusCheck(_ feature: PlusFeature) -> some View {
    modifier(DisableWithPlusCheckModifier(feature: feature))
  }
}
