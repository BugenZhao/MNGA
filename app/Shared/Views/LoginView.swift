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

fileprivate class LoginViewUIDelegate: NSObject, WKUIDelegate {
  let parent: LoginView

  init(parent: LoginView) {
    self.parent = parent
    super.init()
  }

  func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
    parent.alertCompletion = completionHandler
    parent.alertMessage = message
  }
}

struct LoginView: View {
  @StateObject var authStorage = AuthStorage.shared
  @StateObject var webViewStore: WebViewStore

  @State var authing = false

  @State private var delegate: LoginViewUIDelegate? = nil
  @State var alertMessage: String? = nil
  @State var alertCompletion: (() -> Void)? = nil

  let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

  init() {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    self._webViewStore = StateObject(wrappedValue: WebViewStore(webView: webView))
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) { Button(action: close) { Text("Cancel") } }
    ToolbarItem(placement: .mayNavigationBarTrailing) { if authing { ProgressView() } }
  }

  @ViewBuilder
  var inner: some View {
    WebView(webView: webViewStore.webView)
      .onAppear {
      self.delegate = .init(parent: self)
      self.webViewStore.webView.load(URLRequest(url: Constants.URL.login))
      self.webViewStore.webView.uiDelegate = self.delegate
    }.onReceive(timer) { _ in
      self.webViewStore.configuration.websiteDataStore.httpCookieStore.getAllCookies(authWithCookies)
    } .navigationTitleInline(key: "Sign in to NGA")
      .toolbar { toolbar }
      .alert(isPresented: $alertMessage.isNotNil()) { Alert(title: "From NGA".localized, message: alertMessage) }
      .onChange(of: alertMessage) { if $0 == nil, let c = alertCompletion { c(); alertCompletion = nil } }
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
