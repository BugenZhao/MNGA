//
//  SearchModel.swift
//  NGA
//
//  Created by Bugen Zhao on 7/12/21.
//

import Foundation

class SearchModel<T>: ObservableObject {
  @Published var text = ""
  @Published var isEditing = false
  @Published var results = [T]()
  
  @Published var commitFlag = 0

  var isSearching: Bool { isEditing || !text.isEmpty }
}
