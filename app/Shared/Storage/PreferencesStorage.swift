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
  private var unlocked: Bool {
    PaywallModel.shared.isUnlocked
  }

  @Published var showing = false

  static let shared = PreferencesStorage()

  @AppStorage("showSignatureNew") var showSignatureInner = false
  @AppStorage("showAvatar") var showAvatarInner = true
  @AppStorage("usePaginatedDetails") var usePaginatedDetails = false
  @AppStorage("useInAppSafari") var useInAppSafari = true
  @AppStorage("defaultTopicListOrder") var defaultTopicListOrder = TopicListRequest.Order.lastPost
  @AppStorage("topicListHideBlocked") var topicListHideBlocked = false
  @AppStorage("topicListShowRefreshButton") var topicListShowRefreshButton = true
  @AppStorage("themeColorNew") var themeColorInner = ThemeColor.mnga
  @AppStorage("colorScheme") var colorScheme = ColorSchemeMode.auto
  @AppStorage("useInsetGroupedModern") var useInsetGroupedModernInner = true
  @AppStorage("hideMNGAMeta") var hideMNGAMeta = false
  @AppStorage("showPlusInTitle") var showPlusInTitleInner = false

  @AppStorage("requestOption") var requestOptionWrapper = WrappedMessage(inner: RequestOption()) {
    didSet { syncRequestOptionWithLogic() }
  }

  var requestOption: RequestOption {
    get { requestOptionWrapper.inner }
    set { requestOptionWrapper.inner = newValue }
  }

  @AppStorage("postRowSwipeActionLeading") var postRowSwipeActionLeadingInner = false
  @AppStorage("postRowSwipeVoteFirst") var postRowSwipeVoteFirstInner = false
  @AppStorage("postRowShowUserDetails") var postRowShowUserDetailsInner = true
  @AppStorage("postRowShowUserRegDate") var postRowShowUserRegDateInner = false
  @AppStorage("postRowDateTimeStrategy") var postRowDateTimeStrategyInner = DateTimeTextView.Strategy.automatic
  @AppStorage("postRowShowAuthorIndicator") var postRowShowAuthorIndicatorInner = true
  @AppStorage("postRowLargerFont") var postRowLargerFont = false
  @AppStorage("postRowDimImagesInDarkMode") var postRowDimImagesInDarkModeInner = false
  @AppStorage("postRowImageScale") var postRowImageScale = ContentImageScale.fullSize
  @AppStorage("resumeTopicFrom") var resumeTopicFromInner = TopicResumeFrom.none

  @AppStorage("autoOpenInBrowserWhenBannedNew") var autoOpenInBrowserWhenBanned = false
  @AppStorage("topicDetailsWebApiStrategy") var topicDetailsWebApiStrategy = TopicDetailsRequest.WebApiStrategy.disabled
  @AppStorage("alwaysShareImageAsFile") var alwaysShareImageAsFile = false

  // MARK: - Paywalled Preferences

  private func paywalledValue<Value>(_ value: Value, default defaultValue: Value) -> Value {
    unlocked ? value : defaultValue
  }

  var postRowSwipeActionLeading: Bool {
    get { paywalledValue(postRowSwipeActionLeadingInner, default: false) }
    set { postRowSwipeActionLeadingInner = newValue }
  }

  var postRowSwipeVoteFirst: Bool {
    get { paywalledValue(postRowSwipeVoteFirstInner, default: false) }
    set { postRowSwipeVoteFirstInner = newValue }
  }

  var postRowDateTimeStrategy: DateTimeTextView.Strategy {
    get { paywalledValue(postRowDateTimeStrategyInner, default: .automatic) }
    set { postRowDateTimeStrategyInner = newValue }
  }

  var showSignature: Bool {
    get { paywalledValue(showSignatureInner, default: false) }
    set { showSignatureInner = newValue }
  }

  var showAvatar: Bool {
    get { paywalledValue(showAvatarInner, default: true) }
    set { showAvatarInner = newValue }
  }

  var postRowShowAuthorIndicator: Bool {
    get { paywalledValue(postRowShowAuthorIndicatorInner, default: true) }
    set { postRowShowAuthorIndicatorInner = newValue }
  }

  var postRowShowUserDetails: Bool {
    get { paywalledValue(postRowShowUserDetailsInner, default: true) }
    set { postRowShowUserDetailsInner = newValue }
  }

  var postRowShowUserRegDate: Bool {
    get { paywalledValue(postRowShowUserRegDateInner, default: false) }
    set { postRowShowUserRegDateInner = newValue }
  }

  var postRowDimImagesInDarkMode: Bool {
    get { paywalledValue(postRowDimImagesInDarkModeInner, default: false) }
    set { postRowDimImagesInDarkModeInner = newValue }
  }

  var themeColor: ThemeColor {
    get { paywalledValue(themeColorInner, default: .mnga) }
    set { themeColorInner = newValue }
  }

  var useInsetGroupedModern: Bool {
    get { paywalledValue(useInsetGroupedModernInner, default: true) }
    set { useInsetGroupedModernInner = newValue }
  }

  var resumeTopicFrom: TopicResumeFrom {
    get { paywalledValue(resumeTopicFromInner, default: .none) }
    set { resumeTopicFromInner = newValue }
  }

  var showPlusInTitle: Bool {
    get { paywalledValue(showPlusInTitleInner, default: false) }
    set { showPlusInTitleInner = newValue }
  }

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
