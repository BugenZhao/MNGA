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

enum MNGANavigationIdentifier: Hashable {
  case topicID(String)
  case forumID(ForumId)
}

extension URL {
  var mngaNavigationIdentifier: MNGANavigationIdentifier? {
    let parser = URLParser<Void>()

    if self.scheme == Constants.MNGA.scheme {
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
    }

    if Constants.URL.hosts.contains(self.host ?? ""),
      let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
      if components.path.contains("read.php"),
        let tid = components.queryItems?.first(where: { $0.name == "tid" })?.value {
        return .topicID(tid)
      } else if components.path.contains("thread.php"),
        let stid = components.queryItems?.first(where: { $0.name == "stid" })?.value {
        return .forumID(.with { $0.stid = stid })
      } else if components.path.contains("thread.php"),
        let fid = components.queryItems?.first(where: { $0.name == "fid" })?.value {
        return .forumID(.with { $0.fid = fid })
      }
    }

    return nil
  }
}

class SchemesModel: ObservableObject {
  @Published var topicID: String?
  @Published var forumID: ForumId?

  var isActive: Bool {
    self.topicID != nil
      || self.forumID != nil
  }

  func clear() {
    self.topicID = nil
    self.forumID = nil
  }

  func navigateID(for url: URL) -> MNGANavigationIdentifier? {
    if let id = url.mngaNavigationIdentifier {
      return id
    }
    return nil
  }

  func canNavigateTo(_ url: URL) -> Bool {
    navigateID(for: url) != nil
  }

  func onNavigateToURL(_ url: URL) -> Bool {
    guard let id = navigateID(for: url) else { return false }

    let action = {
      switch id {
      case .topicID(let tid):
        self.topicID = tid
      case .forumID(let id):
        self.forumID = id
      }
    }
    DispatchQueue.main.async {
      if self.isActive {
        self.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8, execute: action)
      } else {
        action()
      }
    }

    logger.info("navigated url `\(url)`")
    return true
  }
}

struct SchemesNavigationModifier: ViewModifier {
  @ObservedObject var model: SchemesModel

  @State var urlFromPasteboardForAlert: URL?

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
      .alert(isPresented: $urlFromPasteboardForAlert.isNotNil()) {
      let url = urlFromPasteboardForAlert
      return Alert(title: Text("Navigate to Link from Pasteboard?"), message: Text(url?.absoluteString ?? ""), primaryButton: .default(Text("Navigate")) { if let url = url, model.canNavigateTo(url) { let _ = model.onNavigateToURL(url) } }, secondaryButton: .cancel())
    }
      .onChange(of: urlFromPasteboardForAlert) { if $0 == nil { copyToPasteboard(string: "") } }
      .onReceive(NotificationCenter.default.publisher(for: AppKitOrUIKitApplication.didBecomeActiveNotification)) { _ in
      #if os(iOS)
        UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { result in
          switch result {
          case .success(_):
            urlFromPasteboardForAlert = UIPasteboard.general.url
          default:
            break
          }
        }
      #endif
    }
  }
}
