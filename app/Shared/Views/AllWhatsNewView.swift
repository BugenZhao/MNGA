//
//  AllWhatsNewView.swift
//  MNGA
//
//  Created by Bugen Zhao on 2025/11/04.
//

import SwiftUI
import WhatsNewKit

extension WhatsNew.Version {
  var betterDescription: String {
    if patch == 0 {
      "\(major).\(minor)"
    } else {
      "\(major).\(minor).\(patch)"
    }
  }
}

struct AllWhatsNewView: View {
  var whatsNewCollection: [WhatsNew] {
    MNGAWhatsNew().whatsNewCollection
      .sorted(by: { $0.version > $1.version })
      .map { w in
        var w = w
        w.primaryAction = .back
        return w
      }
  }

  var body: some View {
    List {
      ForEach(whatsNewCollection, id: \.id) { w in
        NavigationLink {
          WhatsNewView(whatsNew: w)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        } label: {
          HStack {
            Text(w.version.betterDescription)
            if let current = BuildInfo.current.version,
               current.starts(with: w.version.betterDescription)
            {
              Spacer()
              Text("Current Version").foregroundColor(.secondary)
            }
          }
        }
      }
    }
  }
}
