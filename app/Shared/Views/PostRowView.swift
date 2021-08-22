//
//  PostRowView.swift
//  NGA
//
//  Created by Bugen Zhao on 6/28/21.
//

import Foundation
import SwiftUI

struct PostRowView: View {
  let post: Post
  let useContextMenu: Bool

  @Binding var vote: VotesModel.Vote

  @EnvironmentObject var action: TopicDetailsActionModel
  @EnvironmentObject var postReply: PostReplyModel

  @StateObject var authStorage = AuthStorage.shared
  @StateObject var pref = PreferencesStorage.shared
  @StateObject var users = UsersModel.shared
  @StateObject var attachments = AttachmentsModel()

  private var user: User? {
    self.users.localUser(id: self.post.authorID)
  }

  @ViewBuilder
  var header: some View {
    let floor = (Text("#").font(.footnote) + Text("\(post.floor)").font(.callout))
      .fontWeight(.medium)
      .foregroundColor(.accentColor)

    HStack {
      PostRowUserView.build(post: post)
      Spacer()

      if useContextMenu {
        floor
      } else {
        Menu(content: { menu }) {
          floor
          Image(systemName: "ellipsis")
        }
      }
    }
  }

  @ViewBuilder
  var footer: some View {
    HStack {
      voter
      Spacer()
      Group {
        if !post.alterInfo.isEmpty {
          Image(systemName: "pencil")
        }
        DateTimeTextView.build(timestamp: post.postDate)
        Image(systemName: post.device.icon)
          .frame(width: 10)
      } .foregroundColor(.secondary)
        .font(.footnote)
    }
  }

  @ViewBuilder
  var comments: some View {
    if !post.comments.isEmpty {
      Divider()
      HStack {
        Spacer().frame(width: 6)
        VStack {
          ForEach(post.comments, id: \.hashIdentifiable) { comment in
            PostCommentRowView(comment: comment)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
    }
  }

  @ViewBuilder
  var voter: some View {
    HStack(spacing: 4) {
      Button(action: { doVote(.upvote) }) {
        Image(systemName: vote.state == .up ? "hand.thumbsup.fill" : "hand.thumbsup")
          .foregroundColor(vote.state == .up ? .accentColor : .secondary)
          .frame(height: 24)
      } .buttonStyle(.plain)

      let font = Font.subheadline.monospacedDigit()
      Text("\(max(Int32(post.score) + vote.delta, 0))")
        .foregroundColor(vote.state == .up ? .accentColor : .secondary)
        .font(vote.state == .up ? font.bold() : font)

      Button(action: { doVote(.downvote) }) {
        Image(systemName: vote.state == .down ? "hand.thumbsdown.fill" : "hand.thumbsdown")
          .foregroundColor(vote.state == .down ? .accentColor : .secondary)
          .frame(height: 24)
      } .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  var signature: some View {
    if pref.showSignature, let sigSpans = user?.signature.spans, !sigSpans.isEmpty {
      Divider()
      HStack(alignment: .top) {
        Image(systemName: "signature")
          .foregroundColor(.accentColor)
          .imageScale(.small)
        PostContentView(spans: sigSpans, defaultFont: .subheadline, defaultColor: .secondary)
          .equatable()
          .environment(\.useRedact, false)
      }
    }
  }

  @ViewBuilder
  var content: some View {
    PostContentView(spans: post.content.spans)
      .equatable()
  }

  @ViewBuilder
  var menu: some View {
    Section {
      Label("#\(post.id.pid)", systemImage: "number")
    }
    Section {
      Button(action: { copyContent(post.content.raw) }) {
        Label("Copy Raw Content", systemImage: "doc.on.doc")
      }
      Button(action: { doQuote() }) {
        Label("Quote", systemImage: "quote.bubble")
      }
      Button(action: { doComment() }) {
        Label("Comment", systemImage: "tag")
      }
      if authStorage.authInfo.inner.uid == post.authorID {
        Button(action: { doEdit() }) {
          Label("Edit", systemImage: "pencil")
        }
      }
    }
  }

  var body: some View {
    let view = VStack(alignment: .leading, spacing: 10) {
      header
      content
      footer
      comments
      signature
    } .padding(.vertical, 4)
    #if os(iOS)
      .listRowBackground(action.scrollToPid == self.post.id.pid ? Color.tertiarySystemBackground : nil)
    #endif

    Group {
      if useContextMenu {
        view.contextMenu { menu }
      } else {
        view
      }
    } .onAppear { self.post.attachments.map(\.url).forEach(attachments.add(_:)) }
      .environmentObject(attachments)
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
    }, pageToReload: .last)
  }

  func doComment() {
    postReply.show(action: .with {
      $0.postID = self.post.id
      $0.operation = .comment
    }, pageToReload: .exact(Int(self.post.atPage)))
  }

  func doEdit() {
    postReply.show(action: .with {
      $0.postID = self.post.id
      $0.operation = .modify
    }, pageToReload: .exact(Int(self.post.atPage)))
  }
}
