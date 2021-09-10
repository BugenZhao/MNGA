//
//  UserProfileView.swift
//  UserProfileView
//
//  Created by Bugen Zhao on 2021/9/10.
//

import Foundation
import SwiftUI

struct UserProfileView: View {
  let user: User
  
  var body: some View {
    List {
      UserView(user: user, style: .huge)
    } .navigationBarTitle("User Profile", displayMode: .inline)
  }
}
