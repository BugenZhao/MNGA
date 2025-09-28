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
  @Environment(\.dismiss) private var dismiss

  @State private var products: [Product] = []
  @State private var isLoadingProducts = false
  @State private var didLoadProducts = false
  @State private var purchasingProductID: String?
  @State private var isRestoring = false
  @State private var errorMessage: String?
  @State private var lastKnownUnlocked = false

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
    .background(.systemGroupedBackground)
    .toolbar { toolbarContent }
    .task { await loadProductsIfNeeded() }
    .onAppear { lastKnownUnlocked = paywall.onlineStatus?.isUnlocked ?? false }
    .onChange(of: paywall.onlineStatus) {
      guard let status = $1 else { return }
      handleStatusChange(status)
    }
  }

  private var header: some View {
    VStack(spacing: 16) {
      Image(systemName: "sparkles.rectangle.stack")
        .symbolRenderingMode(.hierarchical)
        .font(.system(size: 64, weight: .semibold))
        .foregroundStyle(.tint)

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
        Text("You're enjoying a Plus trial")
          .font(.headline)
        Text("Trial ends on \(expiration, format: .dateTime.year().month().day())")
          .font(.subheadline)
          .foregroundStyle(.secondary)
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

        if isLoadingProducts {
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

        Button(action: restorePurchases) {
          if isRestoring {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(.primary)
          } else {
            Text("Restore Purchases")
          }
        }
        .buttonStyle(.borderless)
        .disabled(isRestoring)
        .padding(.top, 8)
      }
    }
  }

  private func productsToDisplay(for status: UnlockStatus) -> [Product] {
    switch status {
    case .lite:
      return sortedProducts
    case .trial:
      return sortedProducts.filter { $0.id != Constants.Plus.trialID }
    case .paid:
      return []
    }
  }

  @ViewBuilder
  private func productCard(for product: Product) -> some View {
    let isTrialProduct = product.id == Constants.Plus.trialID
    let isPurchasing = purchasingProductID == product.id

    Button { purchase(product) } label: {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline) {
          Text(product.displayName)
            .font(.headline)
          Spacer()
          Text(product.displayPrice)
            .font(.headline)
        }

        if let offerDescription = offerDescription(for: product) {
          Text(offerDescription)
            .font(.footnote)
            .if(isTrialProduct) { $0.foregroundStyle(.tint) }
        }

        if isPurchasing {
          ProgressView()
            .progressViewStyle(.circular)
        }
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

  private func offerDescription(for product: Product) -> String? {
    if product.id == Constants.Plus.trialID {
      return String(localized: "Try Plus for 14 Days")
    }

    return nil
  }

  private var sortedProducts: [Product] {
    products.sorted { lhs, rhs in
      productOrder(lhs) < productOrder(rhs)
    }
  }

  private func productOrder(_ product: Product) -> Int {
    if product.id == Constants.Plus.trialID {
      return 0
    }
    if product.id == Constants.Plus.unlockID {
      return 1
    }
    if let index = Constants.Plus.ids.firstIndex(of: product.id) {
      return index
    }
    return Constants.Plus.ids.count
  }

  private func loadProductsIfNeeded() async {
    if didLoadProducts { return }
    await MainActor.run {
      isLoadingProducts = true
      errorMessage = nil
      didLoadProducts = true
    }

    do {
      let fetched = try await Product.products(for: Set(Constants.Plus.ids))
      await MainActor.run {
        products = fetched
        isLoadingProducts = false
      }
    } catch {
      await MainActor.run {
        errorMessage = error.localizedDescription
        isLoadingProducts = false
      }
    }
  }

  private func purchase(_ product: Product) {
    Task {
      await MainActor.run {
        purchasingProductID = product.id
        errorMessage = nil
      }

      do {
        let result = try await product.purchase()

        switch result {
        case let .success(verification):
          if case let .verified(transaction) = verification {
            await transaction.finish()
            await paywall.updateStatus()
            await MainActor.run {
              purchasingProductID = nil
            }
          } else {
            await handleUnverifiedPurchase()
          }
        case .pending:
          break
        case .userCancelled:
          break
        @unknown default:
          break
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
        }
      }

      await MainActor.run {
        purchasingProductID = nil
      }
    }
  }

  private func handleUnverifiedPurchase() async {
    await MainActor.run {
      errorMessage = String(localized: "We couldn't verify your purchase. Please try again.")
    }
  }

  private func restorePurchases() {
    Task {
      await MainActor.run {
        isRestoring = true
        errorMessage = nil
      }

      do {
        try await AppStore.sync()
        await paywall.updateStatus()
        await MainActor.run {
          if paywall.onlineStatus?.isUnlocked == true {
            dismiss()
          }
        }
      } catch {
        await MainActor.run {
          errorMessage = error.localizedDescription
        }
      }

      await MainActor.run {
        isRestoring = false
      }
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItem(placement: .navigationBarTrailing) {
      Button(action: { dismiss() }) {
        Image(systemName: "xmark")
      }
    }
  }

  private func handleStatusChange(_ status: UnlockStatus) {
    let unlocked = status.isUnlocked
    if unlocked, !lastKnownUnlocked {
      dismiss()
    }
    lastKnownUnlocked = unlocked
  }
}

struct PlusSheetView: View {
  var body: some View {
    NavigationStack {
      PlusView()
    }
  }
}
