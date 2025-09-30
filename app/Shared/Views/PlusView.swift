//
//  PlusView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/09/28.
//

import Foundation
import StoreKit
import SwiftUI

struct UnlockStatusDebugPickerView: View {
  @EnvironmentObject var paywall: PaywallModel

  var body: some View {
    Picker(selection: $paywall.debugOverride, label: Text("Override Unlock Status")) {
      ForEach(UnlockStatus.debugAllCases, id: \.self) { status in
        let desc = if let status { String(describing: status) } else { "None" }
        Text(desc).tag(status)
      }
    }
  }
}

struct PlusView: View {
  @EnvironmentObject var paywall: PaywallModel
  @Environment(\.dismiss) var dismiss

  @State private var allProducts: [Product]?
  @State private var purchasingProductID: String?
  @State private var isRestoring = false
  @State private var isRedeeming = false
  @State private var errorMessage: String?

  var isInProgress: Bool {
    purchasingProductID != nil || isRestoring
  }

  var body: some View {
    VStack(spacing: 0) {
      if let status = paywall.onlineStatus {
        ScrollView {
          VStack(spacing: 28) {
            header

            statusSection(for: status)

            productSection(for: status)

            if let errorMessage {
              Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
            }

            #if DEBUG
              debug
            #endif
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 32)
          .frame(maxWidth: .infinity)
        }
      } else {
        ProgressView()
          .padding()
      }
    }
    .background(Color(.systemGroupedBackground).ignoresSafeArea())
    .toolbar { toolbar }
    .offerCodeRedemption(isPresented: $isRedeeming) { result in Task { await redeemCompletion(result) } }
    .storeProductsTask(for: Constants.Plus.ids) { allProducts = $0.products }
  }

  private var debug: some View {
    UnlockStatusDebugPickerView()
  }

  private var header: some View {
    VStack(spacing: 16) {
      Image(systemName: "sparkles.rectangle.stack")
        .symbolRenderingMode(.hierarchical)
        .foregroundStyle(.tint)
        .font(.system(size: 64, weight: .semibold))

      VStack(spacing: 12) {
        Text("Unlock Plus")
          .font(.largeTitle).bold()
          .multilineTextAlignment(.center)

        Text("Plus Explanation")
          .font(.body)
          .multilineTextAlignment(.center)
      }
    }
  }

  @ViewBuilder
  private func statusSection(for status: UnlockStatus) -> some View {
    switch status {
    case .paid:
      VStack(spacing: 12) {
        Label {
          Text("Plus Unlocked")
            .font(.title3).bold()
        } icon: {
          Image(systemName: "checkmark.seal.fill")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(.green)
        }

        Text("Plus Thanks")
          .font(.callout)
          .multilineTextAlignment(.center)
          .foregroundStyle(.secondary)
      }
      .padding()
      .background(cardBackground)

    case let .trial(expiration):
      VStack(spacing: 8) {
        if status.trialValid ?? false {
          Text("You're enjoying a Plus trial")
            .font(.headline)
          Text("Trial ends on \(expiration, format: .dateTime.year().month().day())")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        } else {
          Text("Your Plus trial has expired")
            .font(.headline)
        }
      }
      .padding()
      .frame(maxWidth: .infinity)
      .background(cardBackground)

    case .lite:
      EmptyView()
    }
  }

  @ViewBuilder
  private func productSection(for status: UnlockStatus) -> some View {
    switch status {
    case .paid:
      EmptyView()
    case .trial, .lite:
      VStack(spacing: 16) {
        let displayProducts = productsToDisplay(for: status)

        if allProducts == nil {
          ProgressView()
            .controlSize(.large)
        } else if displayProducts.isEmpty {
          Text("Products unavailable. Please try again later.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        } else {
          ForEach(displayProducts, id: \.id) { product in
            productCard(for: product)
          }
        }

        HStack(spacing: 16) {
          Button(action: { Task { await restorePurchases() } }) {
            Text("Restore Purchases")
          }
          .disabled(isRestoring)

          Button(action: { isRedeeming = true }) {
            Text("Redeem Code")
          }
          .disabled(isRedeeming)
        }
        .buttonStyle(.borderless)
        .padding(.top, 8)
      }
    }
  }

  private func productsToDisplay(for status: UnlockStatus) -> [Product] {
    switch status {
    case .lite:
      sortedProducts
    case .trial:
      sortedProducts.filter { $0.id != Constants.Plus.trialID }
    case .paid:
      []
    }
  }

  @ViewBuilder
  private func productCard(for product: Product) -> some View {
    let isTrialProduct = product.id == Constants.Plus.trialID
    let isPurchasing = purchasingProductID == product.id

    Button { Task { await purchase(product) } } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          Text(product.displayName)
            .font(.headline)
          Spacer()
          Text(product.displayPrice)
            .font(.headline)
        }

        Text(product.description)
          .font(.footnote)
          .if(isTrialProduct) { $0.foregroundStyle(.tint) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(20)
      .background(cardBackground)
      .overlay {
        RoundedRectangle(cornerRadius: 20)
          .stroke(isTrialProduct ? Color.accentColor : Color.clear, lineWidth: 1.5)
      }
    }
    .buttonStyle(.plain)
    .disabled(isPurchasing)
  }

  private var cardBackground: some View {
    RoundedRectangle(cornerRadius: 20, style: .continuous)
      .fill(Color(.secondarySystemGroupedBackground))
  }

  private var sortedProducts: [Product] {
    (allProducts ?? []).sorted(by: { $0.price < $1.price })
  }

  @MainActor
  private func purchase(_ product: Product) async {
    purchasingProductID = product.id
    errorMessage = nil

    do {
      let result = try await product.purchase()

      switch result {
      case let .success(verification):
        if case let .verified(transaction) = verification {
          await transaction.finish()
          await paywall.updateStatus()
          purchasingProductID = nil
        } else {
          errorMessage = "We couldn't verify your purchase. Please try again.".localized
        }
      case .pending, .userCancelled:
        break
      @unknown default:
        break
      }
    } catch {
      errorMessage = error.localizedDescription
    }

    purchasingProductID = nil
  }

  @MainActor
  private func restorePurchases() async {
    isRestoring = true
    errorMessage = nil

    do {
      try await AppStore.sync()
      await paywall.updateStatus()
    } catch {
      errorMessage = error.localizedDescription
    }

    isRestoring = false
  }

  @MainActor
  private func redeemCompletion(_ result: Result<Void, any Error>) async {
    isRedeeming = false

    switch result {
    case .success:
      await paywall.updateStatus()
    case let .failure(error):
      errorMessage = error.localizedDescription
    }
  }

  @ToolbarContentBuilder
  private var toolbar: some ToolbarContent {
    if isInProgress {
      ToolbarItem(placement: .navigationBarTrailing) { ProgressView() }
      ToolbarSpacer(.fixed, placement: .navigationBarTrailing)
    }

    ToolbarItem(placement: .navigationBarTrailing) {
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
      }
    }
  }
}

struct PlusSheetView: View {
  @EnvironmentObject var paywall: PaywallModel

  var body: some View {
    NavigationStack {
      PlusView()
    }
    .if(!paywall.isUnlocked) { $0.interactiveDismissDisabled() }
  }
}
