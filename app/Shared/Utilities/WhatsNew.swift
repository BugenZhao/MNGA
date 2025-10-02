//
//  WhatsNew.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/10/02.
//

import SwiftUI
import WhatsNewKit

func whatsNewTitle(version: String) -> WhatsNew.Title {
    var title = AttributedString(localized: "What's new in MNGA \(version)")
    if let range = title.range(of: "MNGA \(version)") {
        title[range].foregroundColor = .accentColor
    }
    return .init(text: .init(title))
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
                    subtitle: "采用 Liquid Glass 设计语言全面重构，带来更直观的操作逻辑与全新的视觉体验。"
                ),
                .init(
                    image: .init(systemName: "network"),
                    title: "增强的网络模块",
                    subtitle: "显著提升了 API 的稳定性与抗封锁能力，遇到 XML 解析错误和浏览器跳转的几率大幅降低。"
                ),
                .init(
                    image: .init(systemName: "checklist.checked"),
                    title: "大量修复与改进",
                    subtitle: "50 余项 Bug 修复与体验改进，采用 iOS 26 最新 API，使用体验更加稳定丝滑。"
                ),
                .init(
                    image: .init(systemName: "sparkles.2"),
                    title: "Plus 计划全新上线",
                    subtitle: "MNGA Plus 不仅为您解锁更完整的体验，更是我们持续改进和长期维护 MNGA 的唯一动力。"
                ),
            ],
            primaryAction: .init(
                title: "继续"
            ),
            secondaryAction: .init(
                title: "了解 Plus",
                action: .present(PlusSheetView().eraseToAnyView())
            )
        )
    }

    static let environment = WhatsNewEnvironment(
        versionStore: UserDefaultsWhatsNewVersionStore(),
        whatsNewCollection: Self()
    )

    #if DEBUG
        static func debugReset() {
            UserDefaultsWhatsNewVersionStore().removeAll()
        }
    #endif
}
