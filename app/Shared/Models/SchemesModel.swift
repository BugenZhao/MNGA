//
//  SchemesModel.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/11/19.
//

import Foundation
import Crossroad
import SwiftUI

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

  func onOpenMNGAScheme(_ url: URL) {
    guard let id = url.mngaSchemeIdentifier else { return }

    switch id {
    case .topicID(let tid):
      self.topicID = tid
    case .forumID(let id):
      self.forumID = id
    }
  }
}

struct SchemesNavigationView: View {
  @ObservedObject var model: SchemesModel

  var body: some View {
    Group {
      NavigationLink(destination: TopicDetailsView.build(id: model.topicID ?? ""), isActive: $model.topicID.isNotNil()) { }
      NavigationLink(destination: TopicListView.build(id: model.forumID ?? .init()), isActive: $model.forumID.isNotNil()) { }
    } .hidden()
  }
}
