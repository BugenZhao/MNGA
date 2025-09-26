//
//  SchemesModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/19.
//

import Crossroad
import Foundation
import SwiftUI
import SwiftUIX

enum NavigationIdentifier: Hashable {
  case topicID(tid: String, fav: String?)
  case forumID(ForumId)
}

extension NavigationIdentifier {
  var isMNGAMockID: Bool {
    switch self {
    case let .topicID(tid, _):
      tid.isMNGAMockID
    case let .forumID(forumID):
      forumID.fid.isMNGAMockID
    }
  }

  var mngaURL: URL? {
    var components = URLComponents()
    var url: URL?

    switch self {
    case let .topicID(tid, fav):
      components.path = tid
      if let fav {
        components.queryItems = [.init(name: "fav", value: fav)]
      }
      url = components.url(relativeTo: URL(string: Constants.MNGA.topicBase))

    case let .forumID(forumID):
      switch forumID.id {
      case let .fid(fid):
        components.path = fid
        url = components.url(relativeTo: URL(string: Constants.MNGA.forumFBase))
      case let .stid(stid):
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
    case let .topicID(tid, fav):
      components.path = "read.php"
      components.queryItems = [.init(name: "tid", value: tid)]
      if let fav {
        components.queryItems!.append(.init(name: "fav", value: fav))
      }

    case let .forumID(forumId):
      components.path = "thread.php"
      switch forumId.id {
      case let .fid(fid):
        components.queryItems = [.init(name: "fid", value: fid)]
      case let .stid(stid):
        components.queryItems = [.init(name: "stid", value: stid)]
      case .none:
        break
      }
    }

    let url = components.url(relativeTo: URLs.base)
    return url?.absoluteURL
  }
}

extension URL {
  var mngaNavigationIdentifier: NavigationIdentifier? {
    let parser = URLParser<Void>()

    if scheme == Constants.MNGA.scheme {
      if let context = parser.parse(self, in: Constants.MNGA.topicBase + ":tid"),
         let tid: String = context[argument: "tid"]
      {
        let fav: String? = context[parameter: "fav"]
        return .topicID(tid: tid, fav: fav)
      }

      if let context = parser.parse(self, in: Constants.MNGA.forumFBase + ":fid"),
         let fid: String = context[argument: "fid"]
      {
        return .forumID(.with { $0.fid = fid })
      }
      if let context = parser.parse(self, in: Constants.MNGA.forumSTBase + ":stid"),
         let stid: String = context[argument: "stid"]
      {
        return .forumID(.with { $0.stid = stid })
      }

      return nil
    }

    if URLs.hosts.contains(host ?? ""),
       let components = URLComponents(url: self, resolvingAgainstBaseURL: false)
    {
      if components.path.contains("read.php"),
         let tid = components.queryItems?.first(where: { $0.name == "tid" })?.value
      {
        let fav = components.queryItems?.first(where: { $0.name == "fav" })?.value
        return .topicID(tid: tid, fav: fav)
      } else if components.path.contains("thread.php"),
                let stid = components.queryItems?.first(where: { $0.name == "stid" })?.value
      {
        return .forumID(.with { $0.stid = stid })
      } else if components.path.contains("thread.php"),
                let fid = components.queryItems?.first(where: { $0.name == "fid" })?.value
      {
        return .forumID(.with { $0.fid = fid })
      }
    }

    return nil
  }
}

class SchemesModel: ObservableObject {
  @Published var navID: NavigationIdentifier?

  var isActive: Bool {
    navID != nil
  }

  func clear() {
    navID = nil
  }

  func canNavigateTo(_ url: URL) -> Bool {
    url.mngaNavigationIdentifier != nil
  }

  func navigateTo(url: URL) {
    guard let id = url.mngaNavigationIdentifier else { return }

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
  }
}

struct SchemesNavigationModifier: ViewModifier {
  @ObservedObject var model: SchemesModel

  // @State var urlFromPasteboardForAlert: URL?

  @ViewBuilder
  func destination(_ navID: NavigationIdentifier) -> some View {
    switch navID {
    case let .topicID(tid, fav):
      TopicDetailsView.build(id: tid, fav: fav)
    case let .forumID(forumID):
      TopicListView.build(id: forumID)
    }
  }

  func body(content: Content) -> some View {
    content
      .navigationDestination(item: $model.navID) { destination($0) }
    // .alert(isPresented: $urlFromPasteboardForAlert.isNotNil()) {
    //   let url = urlFromPasteboardForAlert
    //   return Alert(title: Text("Navigate to Link from Pasteboard?"), message: Text(url?.absoluteString ?? ""), primaryButton: .default(Text("Navigate")) { if let url, model.canNavigateTo(url) { _ = model.onNavigateToURL(url) } }, secondaryButton: .cancel())
    // }
    // .onChange(of: urlFromPasteboardForAlert) { if $1 == nil { copyToPasteboard(string: "") } }
    // .onReceive(NotificationCenter.default.publisher(for: AppKitOrUIKitApplication.didBecomeActiveNotification)) { _ in
    //   #if os(iOS)
    //     UIPasteboard.general.detectPatterns(for: [\.probableWebURL]) { result in
    //       switch result {
    //       case .success:
    //         if let url = UIPasteboard.general.url, model.canNavigateTo(url) {
    //           urlFromPasteboardForAlert = url
    //         }
    //       default:
    //         break
    //       }
    //     }
    //   #endif
    // }
  }
}
