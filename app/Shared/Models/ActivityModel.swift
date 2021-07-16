//
//  ActivityModel.swift
//  ActivityModel
//
//  Created by Bugen Zhao on 7/17/21.
//

import Foundation
import Combine

class ActivityModel: ObservableObject {
  @Published var activityItems: [Any]? = nil
  
  func put<Item>(_ item: Item) {
    self.activityItems = [item as Any]
  }
}
