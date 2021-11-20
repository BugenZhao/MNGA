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

enum NavigationIdentifier: Hashable {
  case topicID(tid: String, fav: String?)
  case forumID(ForumId)
}

extension NavigationIdentifier {
  var mngaURL: URL? {
    var components = URLComponents()
    var url: URL?

    switch self {
    case .topicID(let tid, let fav):
      components.path = tid
      if let fav = fav {
        components.queryItems = [.init(name: "fav", value: fav)]
      }
      url = components.url(relativeTo: URL(string: Constants.MNGA.topicBase))

    case .forumID(let forumId):
      switch forumId.id {
      case .fid(let fid):
        components.path = fid
        url = components.url(relativeTo: URL(string: Constants.MNGA.forumFBase))
      case .stid(let stid):
        components.path = stid
        url = components.url(relativeTo: URL(string: Constants.MNGA.forumSTBase))
      case .none:
        break
      }
    }

    return url?.absoluteURL
  }

  var webpageURL: URL? {
    var components = URLComponents()

    switch self {
    case .topicID(let tid, let fav):
      components.path = "read.php"
      components.queryItems = [.init(name: "tid", value: tid)]
      if let fav = fav {
        components.queryItems!.append(.init(name: "fav", value: fav))
      }

    case .forumID(let forumId):
      components.path = "thread.php"
      switch forumId.id {
      case .fid(let fid):
        components.queryItems = [.init(name: "fid", value: fid)]
      case .stid(let stid):
        components.queryItems = [.init(name: "stid", value: stid)]
      case .none:
        break
      }
    }

    let url = components.url(relativeTo: Constants.URL.base)
    return url?.absoluteURL
  }
}

extension URL {
  var mngaNavigationIdentifier: NavigationIdentifier? {
    let parser = URLParser<Void>()

    if self.scheme == Constants.MNGA.scheme {
      if let context = parser.parse(self, in: Constants.MNGA.topicBase + ":tid"),
        let tid: String = context[argument: "tid"] {
        let fav: String? = context[parameter: "fav"]
        return .topicID(tid: tid, fav: fav)
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

    if Constants.URL.hosts.contains(self.host ?? ""),
      let components = URLComponents(url: self, resolvingAgainstBaseURL: false) {
      if components.path.contains("read.php"),
        let tid = components.queryItems?.first(where: { $0.name == "tid" })?.value {
        let fav = components.queryItems?.first(where: { $0.name == "fav" })?.value
        return .topicID(tid: tid, fav: fav)
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
  @Published var navID: NavigationIdentifier?

  var isActive: Bool {
    self.navID != nil
  }

  func clear() {
    self.navID = nil
  }

  func navigateID(for url: URL) -> NavigationIdentifier? {
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

    let action = { self.navID = id }
    DispatchQueue.main.async {
      if self.isActive {
        self.clear()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: action)
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

  var navigation: some View {
    let view: AnyView

    switch model.navID {
    case .topicID(let tid, let fav):
      view = TopicDetailsView.build(id: tid, fav: fav).eraseToAnyView()
    case .forumID(let forumID):
      view = TopicListView.build(id: forumID).eraseToAnyView()
    case .none:
      view = EmptyView().eraseToAnyView()
    }

    return NavigationLink(destination: view, isActive: $model.navID.isNotNil()) { } .hidden()
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
