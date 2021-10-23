//
//  LoginView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import WebKit
import SwiftUI
import WebView

struct LoginView: View {
  @StateObject var authStorage = AuthStorage.shared
  @StateObject var webViewStore: WebViewStore

  @State var authing = false

  let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

  init() {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    self._webViewStore = StateObject(wrappedValue: WebViewStore(webView: webView))
  }

  @ViewBuilder
  var closeButton: some View {
    Button(action: close) {
      if authing {
        ProgressView()
      }
    }
  }

  @ViewBuilder
  var inner: some View {
    WebView(webView: webViewStore.webView)
      .onAppear {
      self.webViewStore.webView.load(URLRequest(url: Constants.URL.login))
    }.onReceive(timer) { _ in
      self.webViewStore.configuration.websiteDataStore.httpCookieStore.getAllCookies(authWithCookies)
    } .navigationTitleInline(key: "Sign in to NGA")
      .toolbar { ToolbarItem(placement: .mayNavigationBarTrailing) { closeButton } }
  }

  var body: some View {
    #if os(iOS)
      NavigationView {
        inner
      }
    #elseif os(macOS)
      inner.frame(width: 300, height: 450)
    #endif
  }

  func authWithCookies(_ cookies: [HTTPCookie]) {
    guard let uid = cookies.first(where: { $0.name == "ngaPassportUid" })?.value else { return }
    guard let token = cookies.first(where: { $0.name == "ngaPassportCid" })?.value else { return }

    authing = true
    authStorage.setCurrentAuth(AuthInfo.with {
      $0.uid = uid
      $0.token = token
    })
    authing = false
  }

  func close() {
    authStorage.isSigning = false
  }
}

fileprivate struct LoginPreviewView: View {
  @EnvironmentObject var authStorage: AuthStorage

  var body: some View {
    NavigationView {
      VStack {
        Text("Authed as '\(authStorage.authInfo.uid)'")
        Button(action: { authStorage.clearCurrentAuth() }) {
          Text("Show")
        }
      } .sheet(isPresented: $authStorage.isSigning, content: {
        LoginView()
      })
    }
  }
}

struct LoginView_Previews: PreviewProvider {
  static var previews: some View {
    LoginPreviewView()
      .environmentObject(AuthStorage())
  }
}
