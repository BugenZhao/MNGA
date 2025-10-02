//
//  LoginView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/1/21.
//

import Foundation
import SwiftUI
import WebKit
import WebView

private class LoginViewUIDelegate: NSObject, WKUIDelegate, WKNavigationDelegate {
  let parent: LoginView

  init(parent: LoginView) {
    self.parent = parent
    super.init()
  }

  func webView(_: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame _: WKFrameInfo, completionHandler: @escaping () -> Void) {
    parent.alertCompletion = completionHandler
    parent.alertMessage = message
  }

  func webView(_: WKWebView, didStartProvisionalNavigation _: WKNavigation!) {
    setLoading(loading: true)
  }

  func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
    guard webView.url?.absoluteString == URLs.login.absoluteString else {
      setLoading(loading: false)
      return
    }

    let hideLoginElement = """
    // Disable viewport scaling
    let viewport = document.querySelector('meta[name="viewport"]');
    if (viewport) {
      viewport.setAttribute('content', 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no');
    } else {
      let meta = document.createElement('meta');
      meta.name = 'viewport';
      meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, minimum-scale=1.0, user-scalable=no';
      document.head.appendChild(meta);
    }

    function getElementByXpath(document, path) {
      return document.evaluate(path, document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue;
    }

    let iframe = document.getElementById("iff")

    let loginXpath = '//*[@id="main"]/div/div[3]/a[2]'
    let loginElement = getElementByXpath(iframe.contentDocument, loginXpath)
    loginElement.click()

    let xpaths = [
      // '//*[@id="main"]/div/div[last()-1]', // Register
      // '//*[@id="main"]/div/span[last()]',  // EULA
      // '//*[@id="main"]/div/a[2]',          // QRCode login
      '//*[@id="main"]/div/div[last()]',   // 3rd party login
    ]

    for (let xpath of xpaths) {
      let element = getElementByXpath(iframe.contentDocument, xpath)
      element.style.display = 'none'
    }
    """

    // Give the page/iframe some time to load.
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      webView.evaluateJavaScript(hideLoginElement) { _, err in
        if let err { logger.warning("evaluateJavaScript: \(err)") }
        self.setLoading(loading: false)
      }
    }
  }

  func setLoading(loading: Bool) {
    DispatchQueue.main.async {
      withAnimation {
        self.parent.loading = loading
      }
    }
  }
}

struct LoginView: View {
  @StateObject var authStorage = AuthStorage.shared
  @StateObject var webViewStore: WebViewStore

  @State var authing = false
  @State var loading = true

  @State private var delegate: LoginViewUIDelegate? = nil
  @State var alertMessage: String? = nil
  @State var alertCompletion: (() -> Void)? = nil

  let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

  init() {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    _webViewStore = StateObject(wrappedValue: WebViewStore(webView: webView))
  }

  @ToolbarContentBuilder
  var toolbar: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) { Button(role: .cancel, action: close) { Image(systemName: "xmark") } }
    ToolbarItem(placement: .mayNavigationBarTrailing) { if authing { ProgressView() } }

    ToolbarItem(placement: .bottomBar) { Button(action: { load(url: URLs.login) }) { Text("Sign In") } }
    ToolbarSpacer(.fixed, placement: .bottomBar)
    ToolbarItemGroup(placement: .bottomBar) {
      Button(action: { load(url: URLs.agreement) }) { Text("Agreement") }
      Button(action: { load(url: URLs.privacy) }) { Text("Privacy") }
    }
  }

  func load(url: URL) {
    webViewStore.webView.load(URLRequest(url: url))
  }

  @ViewBuilder
  var webView: some View {
    WebView(webView: webViewStore.webView)
      .onAppear {
        delegate = .init(parent: self)
        webViewStore.webView.load(URLRequest(url: URLs.login))
        webViewStore.webView.uiDelegate = delegate
        webViewStore.webView.navigationDelegate = delegate
        load(url: URLs.login)
      }.onReceive(timer) { _ in
        webViewStore.configuration.websiteDataStore.httpCookieStore.getAllCookies(authWithCookies)
      }.navigationTitleInline(key: "Sign in to NGA")
  }

  @ViewBuilder
  var inner: some View {
    ZStack {
      webView.opacity(loading ? 0.0 : 1.0)
      ProgressView().hidden(!loading)
    }.toolbar { toolbar }
      .alert(isPresented: $alertMessage.isNotNil()) { Alert(title: "From NGA".localized, message: alertMessage) }
      .onChange(of: alertMessage) { if $1 == nil, let c = alertCompletion { c(); alertCompletion = nil } }
  }

  var body: some View {
    #if os(iOS)
      NavigationView {
        inner
      }.interactiveDismissDisabled()
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

private struct LoginPreviewView: View {
  @EnvironmentObject var authStorage: AuthStorage

  var body: some View {
    NavigationView {
      VStack {
        Text("Authed as '\(authStorage.authInfo.uid)'")
        Button(action: { authStorage.isSigning = true }) {
          Text("Show")
        }
      }.sheet(isPresented: $authStorage.isSigning, content: {
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
