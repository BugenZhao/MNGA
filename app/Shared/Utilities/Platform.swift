//
//  Platform.swift
//  MNGA
//
//  Created by Bugen Zhao on 2021/10/5.
//

import Foundation
import SwiftUI
import SwiftUIX

private struct MayGroupedListStyleModifier: ViewModifier {
  @StateObject var pref = PreferencesStorage.shared

  func body(content: Content) -> some View {
    #if os(iOS)
      if pref.useInsetGroupedModern {
        content.listStyle(.insetGrouped)
      } else {
        content.listStyle(.grouped)
      }
    #else
      content
    #endif
  }
}

extension View {
  @ViewBuilder
  func mayGroupedListStyle() -> some View {
    modifier(MayGroupedListStyleModifier())
  }

  @ViewBuilder
  func mayInsetGroupedListStyle() -> some View {
    #if os(iOS)
      listStyle(.insetGrouped)
    #else
      self
    #endif
  }
}

extension View {
  func navigationTitleInline(string title: some StringProtocol) -> some View {
    #if os(iOS)
      navigationBarTitle(title, displayMode: .inline)
    #elseif os(macOS)
      navigationTitle(title)
    #endif
  }

  func navigationTitleInline(key title: LocalizedStringKey) -> some View {
    #if os(iOS)
      navigationBarTitle(title, displayMode: .inline)
    #elseif os(macOS)
      navigationTitle(title)
    #endif
  }

  func navigationTitleLarge(string title: some StringProtocol) -> some View {
    #if os(iOS)
      navigationBarTitle(title, displayMode: .large)
    #elseif os(macOS)
      navigationTitle(title)
    #endif
  }

  func navigationTitleLarge(key title: LocalizedStringKey) -> some View {
    #if os(iOS)
      navigationBarTitle(title, displayMode: .large)
    #elseif os(macOS)
      navigationTitle(title)
    #endif
  }
}

func copyToPasteboard(_ content: Any) {
  if let text = content as? String {
    copyToPasteboard(string: text)
  } else if let url = content as? URL {
    copyToPasteboard(string: url.absoluteString)
  } else if let image = content as? AppKitOrUIKitImage {
    copyToPasteboard(image: image)
  }
}

func copyToPasteboard(string: String) {
  #if os(iOS)
    UIPasteboard.general.string = string
  #elseif os(macOS)
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.writeObjects([string as NSString])
  #endif
}

func copyToPasteboard(image: AppKitOrUIKitImage) {
  #if os(iOS)
    UIPasteboard.general.image = image
  #elseif os(macOS)
    let pb = NSPasteboard.general
    pb.clearContents()
    pb.writeObjects([image])
  #endif
}

extension ToolbarItemPlacement {
  static var mayNavigationBarLeading: Self {
    #if os(iOS)
      navigationBarLeading
    #else
      navigation
    #endif
  }

  static var mayNavigationBarLeadingOrAction: Self {
    #if os(iOS)
      navigationBarLeading
    #else
      primaryAction
    #endif
  }

  static var mayNavigationBarTrailing: Self {
    #if os(iOS)
      navigationBarTrailing
    #else
      automatic
    #endif
  }

  static var mayBottomBar: Self {
    #if os(iOS)
      bottomBar
    #else
      status
    #endif
  }
}

#if os(macOS)
  extension Color {
    static var secondarySystemGroupedBackground: Self {
      Color(NSColor.textBackgroundColor)
    }

    static var systemGroupedBackground: Self {
      Color(NSColor.windowBackgroundColor)
    }
  }
#endif

struct MaybeToolbarSpacer: ToolbarContent {
  enum MySpacerSizing {
    case flexible
    case fixed
  }

  let sizing: MySpacerSizing
  let placement: ToolbarItemPlacement

  init(_ sizing: MySpacerSizing = .flexible, placement: ToolbarItemPlacement = .automatic) {
    self.sizing = sizing
    self.placement = placement
  }

  var body: some ToolbarContent {
    if #available(iOS 26.0, *) {
      let sizing: SpacerSizing = switch sizing {
      case .flexible: .flexible
      case .fixed: .fixed
      }
      ToolbarSpacer(sizing, placement: placement)
    } else {
      if case .flexible = sizing {
        ToolbarItem(placement: placement) { Spacer() }
      }
    }
  }
}

extension ButtonRole {
  static var maybeConfirm: Self? {
    if #available(iOS 26.0, *) {
      .confirm
    } else {
      nil
    }
  }
}

extension ToolbarContent {
  @ToolbarContentBuilder
  func maybeMatchedTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some ToolbarContent {
    if #available(iOS 26.0, *) {
      matchedTransitionSource(id: id, in: namespace)
    } else {
      self
    }
  }
}

extension View {
  @ViewBuilder
  func maybeNavigationTransition(_ style: some NavigationTransition) -> some View {
    if #available(iOS 26.0, *) {
      navigationTransition(style)
    } else {
      // Although it's also available on iOS 18, we always pair it with `matchedTransitionSource`
      // on toolbar items which is only available on iOS 26.
      self
    }
  }
}

extension View {
  @ViewBuilder
  func maybeNavigationSubtitle(localized subtitleKey: LocalizedStringKey) -> some View {
    if #available(iOS 26.0, *) {
      navigationSubtitle(subtitleKey)
    } else {
      self
    }
  }

  @ViewBuilder
  func maybeNavigationSubtitle(_ subtitle: some StringProtocol) -> some View {
    if #available(iOS 26.0, *) {
      navigationSubtitle(subtitle)
    } else {
      self
    }
  }
}

struct MaybeBottomBarSearchToolbarItem: ToolbarContent {
  let compatAsSpacer: Bool

  init(compatAsSpacer: Bool = false) {
    self.compatAsSpacer = compatAsSpacer
  }

  var body: some ToolbarContent {
    if #available(iOS 26.0, *) {
      DefaultToolbarItem(kind: .search, placement: .bottomBar)
    } else {
      if compatAsSpacer {
        MaybeToolbarSpacer(.flexible, placement: .bottomBar)
      }
    }
  }
}

extension View {
  @ViewBuilder
  func maybeGlassEffect(in shape: some Shape, interactive: Bool = false, tint: Color? = nil) -> some View {
    if #available(iOS 26.0, *) {
      glassEffect(.regular.interactive(interactive).tint(tint), in: shape)
    } else {
      self
    }
  }
}

extension String {
  var maybeCircledSymbol: String {
    if #available(iOS 26.0, *) {
      self
    } else {
      "\(self).circle"
    }
  }
}
