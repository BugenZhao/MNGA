//
//  PostRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI
import SDWebImageSwiftUI

struct PostRowUserView: View, Equatable {
  static func == (lhs: PostRowUserView, rhs: PostRowUserView) -> Bool {
    return lhs.post.id == rhs.post.id
  }

  let post: Post

  @State var showId = false

  var user: User? {
    try? (logicCall(.localUser(.with { $0.userID = post.authorID })) as LocalUserResponse).user
  }

  @ViewBuilder
  func buildAvatar(user: User?) -> some View {
    let placeholder = Image(systemName: "person.circle.fill")
      .resizable()

    if let url = URL(string: user?.avatarURL ?? "") {
      WebImage(url: url)
        .resizable()
        .placeholder(placeholder)
    } else {
      placeholder
    }
  }

  var body: some View {
    let user = self.user

    HStack {
      buildAvatar(user: user)
        .foregroundColor(.accentColor)
        .frame(width: 36, height: 36)
        .clipShape(Circle())

      VStack(alignment: .leading, spacing: 2) {
        Group {
          if showId {
            Text(post.authorID)
          } else {
            Text(user?.name ?? post.authorID)
          }
        } .font(.subheadline)
          .onTapGesture { withAnimation { self.showId.toggle() } }

        HStack(spacing: 6) {

          HStack(spacing: 2) {
            Image(systemName: "text.bubble")
            Text("\(user?.postNum ?? 0)")
          } .foregroundColor((user?.postNum ?? 50 < 50) ? .red : .secondary)
          HStack(spacing: 2) {
            Image(systemName: "calendar")
            Text(Date(timeIntervalSince1970: TimeInterval(user?.regDate ?? 0)), style: .date)
          }
          HStack(spacing: 2) {
            Image(systemName: "flag")
            Text("\(user?.fame ?? 0)")
          } .foregroundColor((user?.fame ?? 0 < 0) ? .red : .secondary)

        } .font(.footnote)
          .foregroundColor(.secondary)
      }
    }
  }
}

struct PostRowView: View {
  let post: Post

  @State var showPostId = false

  @Binding var vote: VotesModel.Vote
  
  @EnvironmentObject var postScroll: PostScrollModel
  @EnvironmentObject var postReply: PostReplyModel

  @ViewBuilder
  var header: some View {
    HStack {
      PostRowUserView(post: post)
        .equatable()
      Spacer()
      (Text("#").font(.footnote) + Text(showPostId ? post.id.pid : "\(post.floor)").font(.callout))
        .fontWeight(.medium)
        .foregroundColor(.accentColor)
        .onTapGesture { withAnimation { self.showPostId.toggle() } }
    }
  }

  @ViewBuilder
  var footer: some View {
    HStack {
      voter
      Spacer()
      Group {
        DateTimeTextView.build(timestamp: post.postDate)
        Image(systemName: post.device.icon)
          .frame(width: 10)
      } .foregroundColor(.secondary)
        .font(.footnote)
    }
  }

  @ViewBuilder
  var voter: some View {
    HStack(spacing: 4) {
      Image(systemName: vote.state == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
        .foregroundColor(vote.state == .up ? .accentColor : .secondary)
        .frame(height: 24)
        .onTapGesture { doVote(.upvote) }

      Text("\(max(Int32(post.score) + vote.delta, 0))")
        .foregroundColor(vote.state != .none ? .accentColor : .secondary)
        .font(.subheadline.monospacedDigit())

      Image(systemName: vote.state == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
        .foregroundColor(vote.state == .down ? .accentColor : .secondary)
        .frame(height: 24)
        .onTapGesture { doVote(.downvote) }
    }
  }

  @ViewBuilder
  var content: some View {
    PostContentView(spans: post.content.spans)
      .equatable()
  }
  
  @ViewBuilder
  var menu: some View {
    Button(action: { copyContent(post.content.raw) }) {
      Label("Copy Raw Content", systemImage: "doc.on.doc")
    }
    Button(action: { doQuote() }) {
      Label("Quote", systemImage: "quote.bubble")
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      header
      content
      footer
    } .padding(.vertical, 4)
      .contextMenu { menu }
    #if os(iOS)
      .listRowBackground(postScroll.pid == self.post.id.pid ? Color.tertiarySystemBackground : nil)
    #endif
  }

  func copyContent(_ content: String) {
    #if os(iOS)
      UIPasteboard.general.string = content
    #elseif os(macOS)
      let pb = NSPasteboard.general
      pb.clearContents()
      pb.writeObjects([content as NSString])
    #endif
  }

  func doVote(_ operation: PostVoteRequest.Operation) {
    logicCallAsync(.postVote(.with {
      $0.postID = post.id
      $0.operation = operation
    })) { (response: PostVoteResponse) in
      if !response.hasError {
        withAnimation {
          self.vote.state = response.state
          self.vote.delta += response.delta
          #if os(iOS)
            if self.vote.state != .none {
              HapticUtils.play(style: .light)
            }
          #endif
        }
      } else {
        // not used
      }
    }
  }
  
  func doQuote() {
    postReply.show(action: .with {
      $0.postID = self.post.id
      $0.operation = .quote
    })
  }
}
