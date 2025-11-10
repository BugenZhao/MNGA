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
  @Published var showing = false

  static let shared = PreferencesStorage()

  @AppStorage("showSignatureNew") var showSignature = false
  @AppStorage("showAvatar") var showAvatar = true
  @AppStorage("usePaginatedDetails") var usePaginatedDetails = false
  @AppStorage("useInAppSafari") var useInAppSafari = true
  @AppStorage("defaultTopicListOrder") var defaultTopicListOrder = TopicListRequest.Order.lastPost
  @AppStorage("topicListHideBlocked") var topicListHideBlocked = false
  @AppStorage("topicListShowRefreshButton") var topicListShowRefreshButton = true
  @AppStorage("themeColorNew") var themeColor = ThemeColor.mnga
  @AppStorage("colorScheme") var colorScheme = ColorSchemeMode.auto
  @AppStorage("useInsetGroupedModern") var useInsetGroupedModern = true
  @AppStorage("hideMNGAMeta") var hideMNGAMeta = false
  @AppStorage("showPlusInTitle") var showPlusInTitle = false

  @AppStorage("requestOption") var requestOptionWrapper = WrappedMessage(inner: RequestOption()) {
    didSet { syncRequestOptionWithLogic() }
  }

  var requestOption: RequestOption {
    get { requestOptionWrapper.inner }
    set { requestOptionWrapper.inner = newValue }
  }

  @AppStorage("postRowSwipeActionLeading") var postRowSwipeActionLeading = false
  @AppStorage("postRowSwipeVoteFirst") var postRowSwipeVoteFirst = false
  @AppStorage("postRowShowUserDetails") var postRowShowUserDetails = true
  @AppStorage("postRowShowUserRegDate") var postRowShowUserRegDate = false
  @AppStorage("postRowDateTimeStrategy") var postRowDateTimeStrategy = DateTimeTextView.Strategy.automatic
  @AppStorage("postRowShowAuthorIndicator") var postRowShowAuthorIndicator = true
  @AppStorage("postRowLargerFont") var postRowLargerFont = false
  @AppStorage("postRowDimImagesInDarkMode") var postRowDimImagesInDarkMode = false
  @AppStorage("postRowImageScale") var postRowImageScale = ContentImageScale.fullSize
  @AppStorage("resumeTopicFrom") var resumeTopicFrom = TopicResumeFrom.none

  @AppStorage("autoOpenInBrowserWhenBannedNew") var autoOpenInBrowserWhenBanned = false
  @AppStorage("topicDetailsWebApiStrategy") var topicDetailsWebApiStrategy = TopicDetailsRequest.WebApiStrategy.disabled

  // MARK: - Debug

  @AppStorage("debugResetTips") var debugResetTips = false
  @AppStorage("debugResetWhatsNew") var debugResetWhatsNew = false

  init() {
    syncRequestOptionWithLogic()
  }

  func syncRequestOptionWithLogic() {
    let _: SetRequestOptionResponse = try! logicCall(.setRequestOption(.with { $0.option = self.requestOption }))
  }
}
