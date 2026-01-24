//
//  WhatsNew.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/10/02.
//

import SwiftUI
import WhatsNewKit

private func whatsNewTitle(version: String) -> WhatsNew.Title {
  var title = AttributedString(localized: "What's new in MNGA \(version)")
  if let range = title.range(of: "MNGA \(version)") {
    title[range].foregroundColor = .accentColor
  }
  return .init(text: .init(title))
}

extension WhatsNew.PrimaryAction {
  static var `continue`: Self {
    .init(title: "Continue".localizedWNText)
  }

  static var back: Self {
    .init(title: "Back".localizedWNText)
  }

  static var done: Self {
    .init(title: "Done".localizedWNText)
  }
}

extension WhatsNew.SecondaryAction {
  static var checkOutPlus: Self {
    .init(
      title: "Check out Plus".localizedWNText,
      action: .present(PlusSheetView().eraseToAnyView()),
    )
  }
}

extension String {
  var localizedWNText: WhatsNew.Text {
    .init(localized)
  }

  var localizedWNTitle: WhatsNew.Title {
    .init(text: localizedWNText)
  }
}

struct MNGAWhatsNew: WhatsNewCollectionProvider {
  var whatsNewCollection: WhatsNewCollection {
    WhatsNew(
      version: "2.0",
      title: whatsNewTitle(version: "2.0"),
      features: [
        .init(
          image: .init(systemName: "26.circle"),
          title: "Liquid Glass 全新设计",
          subtitle: "采用 Liquid Glass 设计语言全面重构，带来更直观的操作逻辑与全新的视觉体验。",
        ),
        .init(
          image: .init(systemName: "network"),
          title: "增强的网络模块",
          subtitle: "显著提升了 API 的稳定性与抗封锁能力，遇到 XML 解析错误和浏览器跳转的几率大幅降低。",
        ),
        .init(
          image: .init(systemName: "checklist.checked"),
          title: "大量修复与改进",
          subtitle: "50 余项 Bug 修复与体验改进，采用 iOS 26 最新 API，使用体验更加稳定丝滑。",
        ),
        .init(
          image: .init(systemName: "sparkles"),
          title: "Plus 计划全新上线",
          subtitle: "MNGA Plus 不仅为您解锁更完整的体验，更是我们持续改进和长期维护 MNGA 的唯一动力。",
        ),
      ],
      primaryAction: .continue,
      secondaryAction: .checkOutPlus,
    )

    WhatsNew(
      version: "2.1",
      title: whatsNewTitle(version: "2.1"),
      features: [
        .init(
          image: .init(systemName: "clock.arrow.circlepath"),
          title: "保存阅读进度",
          subtitle: "自动记录你读过的楼层，久未返回会贴心刷新，一打开就续上最新进度。",
        ),
        .init(
          image: .init(systemName: "bookmark"),
          title: "多收藏夹支持",
          subtitle: "创建、管理多个收藏夹，帮助你精确归类喜爱的帖子。",
        ),
        .init(
          image: .init(systemName: "doc.richtext"),
          title: "帖子内容更生动",
          subtitle: "贴文现可展示骰子结果、表格排版，图片会按偏好智能缩放，看帖更轻松。",
        ),
        .init(
          image: .init(systemName: "checklist.checked"),
          title: "持续修复与改进",
          subtitle: "持续修复已知问题，进一步整合 iOS 26 全新 API，使用体验更加稳定丝滑。",
        ),
      ],
      primaryAction: .continue,
      secondaryAction: .checkOutPlus,
    )

    WhatsNew(
      version: "2.2",
      title: whatsNewTitle(version: "2.2"),
      features: [
        .init(
          image: .init(systemName: "photo.stack"),
          title: "多图翻页浏览",
          subtitle: "图片多也不怕：左右滑动一口气翻完，放大缩小也顺手。",
        ),
        .init(
          image: .init(systemName: "bell.badge"),
          title: "随处打开通知",
          subtitle: "不管你在列表还是看帖，工具栏都能一键直达未读通知，重要消息不迷路。",
        ),
        .init(
          image: .init(systemName: "icloud"),
          title: "收藏版块云端同步",
          subtitle: "开启后，版块收藏会自动随账号同步云端，多台设备间无缝切换。",
        ),
        .init(
          image: .init(systemName: "checklist.checked"),
          title: "阅读体验持续打磨",
          subtitle: "匿名帖子只看作者、帖子列表跳转版块、全新表情输入面板；阅读体验更加流畅舒适。",
        ),
      ],
      primaryAction: .continue,
      secondaryAction: .checkOutPlus,
    )
  }

  static let environment = WhatsNewEnvironment(
    versionStore: UserDefaultsWhatsNewVersionStore(),
    whatsNewCollection: Self(),
  )

  #if DEBUG
    static func debugReset() {
      UserDefaultsWhatsNewVersionStore().removeAll()
    }
  #endif
}
