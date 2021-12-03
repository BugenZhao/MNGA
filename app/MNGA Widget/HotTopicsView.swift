//
//  HotTopicsView.swift
//  MNGA Widget Extension
//
//  Created by Bugen Zhao on 2021/10/6.
//

import Foundation
import SwiftUI

struct HotTopicsView: View {
  let time: Date
  let forum: Forum
  let topics: [Topic]
  let image: PlatformImage?

  var body: some View {
    ZStack {
      LinearGradient(gradient: Gradient(colors: [
        .init("LightColor").opacity(0.2),
        .init("DarkColor").opacity(0.6),
      ]), startPoint: .topLeading, endPoint: .bottomTrailing)
        .edgesIgnoringSafeArea(.all)

      VStack(alignment: .leading, spacing: 8) {
        HStack(spacing: 4) {
          Group {
            if let image = self.image {
              Image(uiImage: image).resizable()
            } else {
              Image("default_forum_icon").resizable()
            }
          }.frame(width: 20, height: 20)
          Text(forum.name)
          Spacer()
          Text(time, style: .date)
            .opacity(0.4)
        }.font(.footnote.bold())
          .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 0)

        Divider()

        VStack(spacing: 6) {
          ForEach(topics.prefix(3), id: \.id) { topic in
            HStack {
              Text(topic.subject.content)
                .font(.subheadline.bold())
                .lineLimit(2)
                .opacity(0.8)
              Spacer()
              Text("\(topic.repliesNum)")
                .font(.headline.monospacedDigit())
                .fontWeight(.heavy)
                .foregroundColor(.init("DarkColor"))
                .shadow(color: .white, radius: 6, x: 0, y: 0)
//              RepliesNumView(num: topic.repliesNum, lastNum: nil)
            }
          }
        }
      }.padding(.horizontal, 12)
        .padding(.vertical, 12)
        .foregroundColor(.black)
    }
  }
}
