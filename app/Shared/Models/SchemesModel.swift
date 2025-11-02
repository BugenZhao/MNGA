//
//  SchemesModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/19.
//

import Combine
import Crossroad
import Foundation
import SwiftUI
import SwiftUIX

enum NavigationIdentifier: Hashable {
  case topicID(tid: String, fav: String?)
  case postID(String)
  case forumID(ForumId)
}

extension NavigationIdentifier {
  var isMNGAMockID: Bool {
    switch self {
    case let .topicID(tid, _):
      tid.isMNGAMockID
    case let .postID(pid):
      pid.isMNGAMockID
    case let .forumID(forumID):
      forumID.fid.isMNGAMockID || forumID.stid.isMNGAMockID
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

    case let .postID(pid):
      components.path = pid
      url = components.url(relativeTo: URL(string: Constants.MNGA.postBase))

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
    guard !isMNGAMockID else { return nil }
    var components = URLComponents()

    switch self {
    case let .topicID(tid, fav):
      components.path = "read.php"
      components.queryItems = [.init(name: "tid", value: tid)]
      if let fav {
        components.queryItems!.append(.init(name: "fav", value: fav))
      }

    case let .postID(pid):
      components.path = "read.php"
      components.queryItems = [.init(name: "pid", value: pid)]

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
      if let context = parser.parse(self, in: Constants.MNGA.postBase + ":pid"),
         let pid: String = context[argument: "pid"]
      {
        return .postID(pid)
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
      if components.path == "/read.php" {
        if let tid = components.queryItems?.first(where: { $0.name == "tid" })?.value {
          let fav = components.queryItems?.first(where: { $0.name == "fav" })?.value
          return .topicID(tid: tid, fav: fav)
        } else if let pid = components.queryItems?.first(where: { $0.name == "pid" })?.value {
          return .postID(pid)
        }
      } else if components.path == "/thread.php" {
        if let stid = components.queryItems?.first(where: { $0.name == "stid" })?.value {
          return .forumID(.with { $0.stid = stid })
        } else if let fid = components.queryItems?.first(where: { $0.name == "fid" })?.value {
          return .forumID(.with { $0.fid = fid })
        }
      }
    }

    return nil
  }
}

// https://stackoverflow.com/questions/67438411/swiftui-onreceive-dont-work-with-uipasteboard-publisher
extension UIPasteboard {
  var hasURLsPublisher: AnyPublisher<Bool, Never> {
    Just(hasURLs)
      .merge(
        with: NotificationCenter.default
          .publisher(for: UIPasteboard.changedNotification, object: self)
          .map { _ in self.hasURLs })
      .merge(
        with: NotificationCenter.default
          .publisher(for: UIApplication.didBecomeActiveNotification, object: nil)
          .map { _ in self.hasURLs })
      .eraseToAnyPublisher()
  }
}

class SchemesModel: ObservableObject {
  @Published var navID: NavigationIdentifier?

  // We can't guarantee it's a valid NGA/MNGA link in the pasteboard.
  @Published var canTryNavigateToPasteboardURL = false

  var cancellables = Set<AnyCancellable>()

  func canNavigateTo(_ url: URL) -> Bool {
    url.mngaNavigationIdentifier != nil
  }

  func navigateTo(url: URL) {
    guard let id = url.mngaNavigationIdentifier else { return }

    navID = nil
    ToastModel.showAuto(.openURL(url))
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      self.navID = id
    }

    logger.info("navigated url `\(url)`")
  }

  init() {
    UIPasteboard.general.hasURLsPublisher
      .sink { has in withAnimation { self.canTryNavigateToPasteboardURL = has } }
      .store(in: &cancellables)
  }

  func navigateToPasteboardURL() {
    guard let url = UIPasteboard.general.url, canNavigateTo(url) else {
      ToastModel.showAuto(.error("Not a valid NGA or MNGA link in the pasteboard."))
      return
    }
    navigateTo(url: url)
  }
}

struct SchemesNavigationModifier: ViewModifier {
  @ObservedObject var model: SchemesModel

  @ViewBuilder
  var destination: some View {
    if let navID = model.navID {
      NavigationStack {
        switch navID {
        case let .topicID(tid, fav):
          TopicDetailsView.build(id: tid, fav: fav)
        case let .postID(pid):
          let postId = PostId.with { $0.pid = pid }
          TopicDetailsView.build(onlyPost: (id: postId, atPage: nil))
        case let .forumID(forumID):
          TopicListView.build(id: forumID)
        }
      }
      .modifier(MainToastModifier.bannerOnly()) // for network error
      .modifier(GlobalSheetsModifier())
    }
  }

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: $model.navID.isNotNil()) { destination }
      .environmentObject(model)
  }
}
