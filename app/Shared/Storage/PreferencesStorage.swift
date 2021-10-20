//
//  PreferencesStorage.swift
//  PreferencesStorage
//
//  Created by Bugen Zhao on 7/20/21.
//

import Foundation
import Combine
import SwiftUI

class PreferencesStorage: ObservableObject {
  static let shared = PreferencesStorage()

  @AppStorage("showTopicSubject") var showTopicSubject = false
  @AppStorage("showSignature") var showSignature = true
  @AppStorage("showAvatar") var showAvatar = true
  @AppStorage("useRedactNew") var useRedact = false
  @AppStorage("usePaginatedDetails") var usePaginatedDetails = true
  @AppStorage("useInAppSafari") var useInAppSafari = true
  @AppStorage("imageViewerEnableZoom") var imageViewerEnableZoom = true
  @AppStorage("defaultTopicListOrder") var defaultTopicListOrder = TopicListRequest.Order.lastPost
  @AppStorage("themeColor") var themeColor = ThemeColor.mnga
}
