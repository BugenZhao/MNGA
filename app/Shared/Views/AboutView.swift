//
//  AboutView.swift
//  AboutView
//
//  Created by Bugen Zhao on 2021/9/19.
//

import Foundation
import SwiftUI

struct AboutView: View {
  var body: some View {
    TopicDetailsView.build(id: "mnga_about_feedback", fav: nil)
  }
}

struct AboutView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      AboutView()
    }.environmentObject(ShortMessagePostModel())
  }
}
