//
//  PreferencesView.swift
//  NGA
//
//  Created by Bugen Zhao on 7/20/21.
//

import Foundation
import SwiftUI

private struct PostRowAppearanceView: View {
  @ObservedObject var pref: PreferencesStorage

  var body: some View {
    Form {
      Section(header: Text("Preview")) {
        PostRowView.build(post: .dummy, isAuthor: true, vote: .constant((state: .up, delta: 0)))
          // PostContentView doesn't seem to correctly refresh when larger font setting changes,
          // as it creates a new state object from the global shared one. This won't be a problem
          // in actual browsing. So here we simply use a trick to force refresh.
          .id("dummy-post-larger-font-\(pref.postRowLargerFont)")
      }

      Section {
        Toggle(isOn: $pref.usePaginatedDetails) {
          Label("Paginated Reading", systemImage: "square.stack")
        }
        Toggle(isOn: $pref.postRowLargerFont) {
          Label("Larger Font", systemImage: "textformat.size")
        }
        Toggle(isOn: $pref.postRowDimImagesInDarkMode) {
          Label("Dim Images in Dark Mode", systemImage: "moon.fill")
        }
      }

      Section {
        Picker(selection: $pref.postRowSwipeActionLeading, label: Label("Swipe Trigger Edge", systemImage: "rectangle.portrait.arrowtriangle.2.outward")) {
          Text("Leading").tag(true)
          Text("Trailing").tag(false)
        }

        Picker(selection: $pref.postRowDateTimeStrategy.animation(), label: Label("Date Display", systemImage: "calendar")) {
          ForEach(DateTimeTextView.Strategy.allCases, id: \.self) { s in
            Text(s.description).tag(s)
          }
        }

        Toggle(isOn: $pref.showSignature.animation()) {
          Label("Show Signature", systemImage: "signature")
        }

        Toggle(isOn: $pref.showAvatar.animation()) {
          Label("Show Avatar", systemImage: "person.crop.circle")
        }

        Toggle(isOn: $pref.postRowShowAuthorIndicator.animation()) {
          Label("Show Author Indicator", systemImage: "person.fill")
        }
        Toggle(isOn: $pref.postRowShowUserDetails.animation()) {
          Label("Show User Details", systemImage: "info.circle")
        }
        if pref.postRowShowUserDetails {
          Toggle(isOn: $pref.postRowShowUserRegDate.animation()) {
            Label("Show User Register Date", systemImage: "calendar")
          }
        }
      }

    }.pickerStyle(.menu)
      .tint(.accentColor)
      .navigationTitleInline(string: "")
  }
}

private struct TopicListAppearanceView: View {
  @ObservedObject var pref: PreferencesStorage

  var body: some View {
    Form {
      Picker(selection: $pref.defaultTopicListOrder, label: Label("Default Order", systemImage: "arrow.up.arrow.down")) {
        ForEach(TopicListRequest.Order.allCases, id: \.self) { order in
          Label(order.description, systemImage: order.icon).tag(order)
        }
      }
    }.pickerStyle(.menu)
      .tint(.accentColor)
      .navigationTitleInline(string: "")
  }
}

struct PreferencesInnerView: View {
  @StateObject var pref = PreferencesStorage.shared
  @EnvironmentObject var paywall: PaywallModel

  @ViewBuilder
  var paywallSection: some View {
    let status = paywall.cachedStatus

    Section(
      header: Text("Plus"),
      footer: Text(status.isPaid ? "Plus Thanks" : "Plus Explanation")
    ) {
      if status.isPaid {
        NavigationLink(destination: PlusView()) {
          Label("Plus Unlocked", systemImage: "star.circle.fill")
        }
      } else {
        if status.isLiteCanTry {
          NavigationLink(destination: PlusView()) {
            Label("Try Plus for 14 Days", systemImage: "star.circle")
          }
        } else {
          NavigationLink(destination: PlusView()) {
            Label("Unlock Plus", systemImage: "star.circle")
          }
        }
      }

      if case let .trial(expiration) = status {
        Text("Trial ends on \(expiration, format: .dateTime.year().month().day())")
      }
    }
  }

  @ViewBuilder
  var appearance: some View {
    Picker(selection: $pref.colorScheme, label: Label("Color Scheme", systemImage: "rays")) {
      ForEach(ColorSchemeMode.allCases, id: \.self) { mode in
        Text(mode.description)
      }
    }
    Picker(selection: $pref.themeColor, label: Label("Theme Color", systemImage: "circle")) {
      ForEach(ThemeColor.allCases, id: \.self) { color in
        Label(color.description, systemImage: "circle.fill")
          .tint(color.color)
          .tag(color)
      }
    }
    Picker(selection: $pref.useInsetGroupedModern, label: Label("List Style", systemImage: "list.bullet.rectangle.portrait")) {
      Text("Compact").tag(false)
      Text("Modern").tag(true)
    }
  }

  @ViewBuilder
  var reading: some View {
    NavigationLink(destination: BlockWordListView()) {
      Label("Block Contents", systemImage: "hand.raised")
    }
    NavigationLink(destination: TopicListAppearanceView(pref: pref)) {
      Label("Topic List Style", systemImage: "list.dash")
    }
    NavigationLink(destination: PostRowAppearanceView(pref: pref)) {
      Label("Topic Details Style", systemImage: "list.bullet.below.rectangle")
    }

    Toggle(isOn: $pref.useInAppSafari) {
      Label("Always Use In-App Safari", systemImage: "safari")
    }
    Toggle(isOn: $pref.hideMNGAMeta) {
      Label("Hide MNGA Meta", systemImage: "eye.slash")
    }
  }

  @ViewBuilder
  var connection: some View {
    Group {
      Picker(selection: $pref.requestOption.baseURLV2, label: Label("Backend", systemImage: "server.rack")) {
        ForEach(URLs.hosts, id: \.self) { host in
          Text(host).tag(URLs.base(for: host)!.absoluteString)
        }
      }
    }.lineLimit(1)

    Group {
      Picker(selection: $pref.requestOption.device.animation(), label: Label("Device Identity", systemImage: "ipad.and.iphone")) {
        ForEach(Device.allCases, id: \.self) { device in
          Label(device.description, systemImage: device.icon).tag(device)
        }
      }

      if pref.requestOption.device == .custom {
        TextField("Custom User-Agent", text: $pref.requestOption.customUa)
          .autocorrectionDisabled(true)
      }
    }
  }

  @ViewBuilder
  var advanced: some View {
    NavigationLink(destination: CacheView()) {
      Label("Cache Management", systemImage: "internaldrive")
    }
  }

  @ViewBuilder
  var special: some View {
    Group {
      Toggle(isOn: $pref.autoOpenInBrowserWhenBanned) {
        Label("Auto Open in Browser when Banned", systemImage: "network")
      }
    }
  }

  var body: some View {
    Form {
      paywallSection

      Section(header: Text("Appearance")) {
        appearance
      }

      Section(header: Text("Reading")) {
        reading
      }

      Section(header: Text("Connection")) {
        connection
      }

      Section(header: Text("Advanced")) {
        advanced
      }

      Section(header: Text("Special"), footer: Text("NGA Workaround")) {
        special
      }
    }
    // Set `pickerStyle` explicitly to fix tint color.
    // https://stackoverflow.com/questions/74157251/why-doesnt-pickers-tint-color-update
    .pickerStyle(.menu)
    .tint(.accentColor)
    .mayInsetGroupedListStyle()
    .navigationTitle("Preferences")
    .preferredColorScheme(pref.colorScheme.scheme) // workaround
  }
}

struct PreferencesView: View {
  var body: some View {
    NavigationStack {
      PreferencesInnerView()
    }
  }
}

struct PreferencesView_Previews: PreviewProvider {
  static let model = PostReplyModel()

  static var previews: some View {
    PreferencesView()
      .environmentObject(model)
  }
}
