//
//  PreferencesStorage.swift
//  PreferencesStorage
//
//  Created by Bugen Zhao on 7/20/21.
//

import Combine
import Foundation
import SwiftUI

class PreferencesStorage: ObservableObject {
  static let shared = PreferencesStorage()

  @AppStorage("showTopicSubjectNew") var showTopicSubject = false
  @AppStorage("showSignatureNew") var showSignature = false
  @AppStorage("showAvatar") var showAvatar = true
  @AppStorage("usePaginatedDetails") var usePaginatedDetails = false
  @AppStorage("useInAppSafari") var useInAppSafari = true
  @AppStorage("imageViewerEnableZoom") var imageViewerEnableZoom = true
  @AppStorage("defaultTopicListOrder") var defaultTopicListOrder = TopicListRequest.Order.lastPost
  @AppStorage("themeColor") var themeColor = ThemeColor.mnga
  @AppStorage("colorScheme") var colorScheme = ColorSchemeMode.auto

  @AppStorage("requestOption") var requestOption = RequestOption() {
    didSet { syncRequestOptionWithLogic() }
  }

  @AppStorage("postRowSwipeActionLeading") var postRowSwipeActionLeading = true
  @AppStorage("postRowShowUserDetails") var postRowShowUserDetails = true
  @AppStorage("postRowShowUserRegDate") var postRowShowUserRegDate = false
  @AppStorage("postRowDateTimeStrategy") var postRowDateTimeStrategy = DateTimeTextView.Strategy.automatic
  @AppStorage("postRowShowAuthorIndicator") var postRowShowAuthorIndicator = true

  init() {
    syncRequestOptionWithLogic()
  }

  func syncRequestOptionWithLogic() {
    let _: SetRequestOptionResponse = try! logicCall(.setRequestOption(.with { $0.option = self.requestOption }))
  }
}
