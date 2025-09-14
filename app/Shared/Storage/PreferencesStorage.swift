//
//  PreferencesStorage.swift
//  PreferencesStorage
//
//  Created by Bugen Zhao on 7/20/21.
//

import Combine
import Foundation
import SwiftUI
import SwiftUIX

class PreferencesStorage: ObservableObject {
  static let shared = PreferencesStorage()

  @AppStorage("showSignatureNew") var showSignature = false
  @AppStorage("showAvatar") var showAvatar = true
  @AppStorage("usePaginatedDetails") var usePaginatedDetails = false
  @AppStorage("useInAppSafari") var useInAppSafari = true
  @AppStorage("imageViewerEnableZoom") var imageViewerEnableZoom = true
  @AppStorage("defaultTopicListOrder") var defaultTopicListOrder = TopicListRequest.Order.lastPost
  @AppStorage("themeColor") var themeColor = ThemeColor.mnga
  @AppStorage("colorScheme") var colorScheme = ColorSchemeMode.auto
  @AppStorage("useInsetGroupedModern") var useInsetGroupedModern = true
  @AppStorage("hideMNGAMeta") var hideMNGAMeta = false

  @AppStorage("requestOption") var requestOptionWrapper = WrappedMessage(inner: RequestOption()) {
    didSet { syncRequestOptionWithLogic() }
  }

  var requestOption: RequestOption {
    get { requestOptionWrapper.inner }
    set { requestOptionWrapper.inner = newValue }
  }

  @AppStorage("postRowSwipeActionLeading") var postRowSwipeActionLeading = false
  @AppStorage("postRowShowUserDetails") var postRowShowUserDetails = true
  @AppStorage("postRowShowUserRegDate") var postRowShowUserRegDate = false
  @AppStorage("postRowDateTimeStrategy") var postRowDateTimeStrategy = DateTimeTextView.Strategy.automatic
  @AppStorage("postRowShowAuthorIndicator") var postRowShowAuthorIndicator = true

  @AppStorage("autoOpenInBrowserWhenBanned") var autoOpenInBrowserWhenBanned = true

  init() {
    syncRequestOptionWithLogic()
  }

  func syncRequestOptionWithLogic() {
    let _: SetRequestOptionResponse = try! logicCall(.setRequestOption(.with { $0.option = self.requestOption }))
  }
}
