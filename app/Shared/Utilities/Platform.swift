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
      if self.pref.useInsetGrouped {
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

  @ViewBuilder
  func compatForumListListStyle() -> some View {
    #if os(iOS)
      if #available(iOS 15.0, *) {
        self
      } else if UserInterfaceIdiom.current == .pad {
        self.listStyle(.sidebar)
      } else {
        self.listStyle(.insetGrouped)
      }
    #else
      self
    #endif
  }
}

extension View {
  func navigationTitleInline<S>(string title: S) -> some View where S: StringProtocol {
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

  func navigationTitleLarge<S>(string title: S) -> some View where S: StringProtocol {
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
      Self.navigationBarLeading
    #else
      Self.navigation
    #endif
  }

  static var mayNavigationBarLeadingOrAction: Self {
    #if os(iOS)
      Self.navigationBarLeading
    #else
      Self.primaryAction
    #endif
  }

  static var mayNavigationBarTrailing: Self {
    #if os(iOS)
      Self.navigationBarTrailing
    #else
      Self.automatic
    #endif
  }

  static var mayBottomBar: Self {
    #if os(iOS)
      Self.bottomBar
    #else
      Self.status
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

extension View {
  @inlinable func maySymbolRenderingModeHierarchical() -> some View {
    Group {
      if #available(iOS 15.0, *) {
        self.symbolRenderingMode(.hierarchical)
      } else {
        self
      }
    }
  }

  @inlinable func maySymbolRenderingModeMulticolor() -> some View {
    Group {
      if #available(iOS 15.0, *) {
        self.symbolRenderingMode(.multicolor)
      } else {
        self
      }
    }
  }
}
