//
//  ContentView.swift
//  Shared
//
//  Created by Bugen Zhao on 6/27/21.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    greeting
      .padding()
  }

  var greeting: some View {
    let request = GreetingRequest.with { $0.verb = "Hello"; $0.name = "Bugen" }
    let response: GreetingResponse = try! logicCall(.greeting(request))

    return Text(response.text)
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
