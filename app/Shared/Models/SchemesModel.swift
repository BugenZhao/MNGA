//
//  SchemesModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/19.
//

import Foundation
import Crossroad
import SwiftUI
import SwiftUIX

enum MNGASchemeIdentifier: Hashable {
  case topicID(String)
  case forumID(ForumId)
}

extension URL {
  var mngaSchemeIdentifier: MNGASchemeIdentifier? {
    let parser = URLParser<Void>()

    if let context = parser.parse(self, in: Constants.MNGA.topicBase + ":tid"),
      let tid: String = context[argument: "tid"] {
      return .topicID(tid)
    }

    if let context = parser.parse(self, in: Constants.MNGA.forumFBase + ":fid"),
      let fid: String = context[argument: "fid"] {
      return .forumID(.with { $0.fid = fid })
    }
    if let context = parser.parse(self, in: Constants.MNGA.forumSTBase + ":stid"),
      let stid: String = context[argument: "stid"] {
      return .forumID(.with { $0.stid = stid })
    }

    return nil
  }
}

class SchemesModel: ObservableObject {
  @Published var topicID: String?
  @Published var forumID: ForumId?

  var isActive: Bool {
    self.topicID != nil
      && self.forumID != nil
  }

  func onOpenMNGAScheme(_ url: URL) -> Bool {
    guard let id = url.mngaSchemeIdentifier else { return false }

    switch id {
    case .topicID(let tid):
      self.topicID = tid
    case .forumID(let id):
      self.forumID = id
    }

    return true
  }

  func onOpenURL(_ url: URL) {
    logger.info("try to open url `\(url)`")

    DispatchQueue.main.async {
      if self.onOpenMNGAScheme(url) {
        ToastModel.showAuto(.openURL(url))
      }
    }
  }
}

struct SchemesNavigationModifier: ViewModifier {
  @ObservedObject var model: SchemesModel

  @ViewBuilder
  var navigation: some View {
    Group {
      NavigationLink(destination: TopicDetailsView.build(id: model.topicID ?? ""), isActive: $model.topicID.isNotNil()) { }
      NavigationLink(destination: TopicListView.build(id: model.forumID ?? .init()), isActive: $model.forumID.isNotNil()) { }
    } .hidden()
  }

  func body(content: Content) -> some View {
    content
      .background { navigation }
      .onReceive(NotificationCenter.default.publisher(for: AppKitOrUIKitApplication.willEnterForegroundNotification)) { _ in
      #if os(iOS)
        UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
          switch result {
          case .success(_):
            if let url = UIPasteboard.general.url { model.onOpenURL(url) }
            copyToPasteboard(string: "")
          default:
            break
          }
        }
      #endif
    }
  }
}
