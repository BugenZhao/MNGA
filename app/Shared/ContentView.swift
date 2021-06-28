//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    NavigationView {
      TopicListView()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    Group {
      ContentView()
      TopicDetailsView(topic: Topic.with {
        $0.id = "27351344"
        $0.subject = "Subject" }
      )
    }
  }
}
