//
//  ActivityModel.swift
//  ActivityModel
//
//  Created by Bugen Zhao on 7/17/21.
//

import Combine
import Foundation

class ActivityModel: ObservableObject {
  @Published var activityItems: [Any]? = nil

  func put(_ item: some Any) {
    activityItems = [item as Any]
  }
}
