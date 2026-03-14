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
    if pref.useInsetGroupedModern {
      content.listStyle(.insetGrouped)
    } else {
      content.listStyle(.grouped)
    }
  }
}

extension View {
  @ViewBuilder
  func mayGroupedListStyle() -> some View {
    modifier(MayGroupedListStyleModifier())
  }

  @ViewBuilder
  func mayInsetGroupedListStyle() -> some View {
    listStyle(.insetGrouped)
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
  UIPasteboard.general.string = string
}

func copyToPasteboard(image: AppKitOrUIKitImage) {
  UIPasteboard.general.image = image
}

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

  @ToolbarContentBuilder
  func maybeSharedBackgroundVisibility(_ visibility: Visibility) -> some ToolbarContent {
    if #available(iOS 26.0, *) {
      sharedBackgroundVisibility(visibility)
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
  let asSpacer: Bool
  let condition: Bool

  init(asSpacer: Bool, if condition: Bool = true) {
    self.asSpacer = asSpacer
    self.condition = condition
  }

  var body: some ToolbarContent {
    if #available(iOS 26.0, *), UserInterfaceIdiom.current == .phone, condition {
      DefaultToolbarItem(kind: .search, placement: .bottomBar)
    } else if asSpacer {
      MaybeToolbarSpacer(.flexible, placement: .bottomBar)
    }
  }
}

extension View {
  @ViewBuilder
  func maybeGlassEffect(in shape: some Shape, interactive: Bool = false) -> some View {
    if #available(iOS 26.0, *) {
      glassEffect(.regular.interactive(interactive), in: shape)
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
