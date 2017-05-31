// @flow

import React, { Component } from 'react'
import { connect } from 'react-redux'
import {
  View,
  FlatList,
} from 'react-native'
import { getSession } from '../../../api/session'
import CommentRow, { type CommentRowProps, type CommentContent } from './CommentRow'
import CommentInput from './CommentInput'
import DrawerState from '../utils/drawer-state'
import SubmissionCommentActions, { type CommentActions } from './actions'
import { type SubmittedContentDataProps } from './SubmittedContent'
import CommentStatus from './CommentStatus'
import Images from '../../../images'
import i18n from 'format-message'
import filesize from 'filesize'
import striptags from 'striptags'

const textSubmission = i18n('Text Submission')

const urlSubmission = i18n('URL Submission')

export class CommentsTab extends Component<any, Props, any> {
  constructor (props: Props) {
    super(props)

    this.state = { shouldShowStatus: this.props.commentRows.some(c => c.pending) }
  }

  makeAComment = (comment: SubmissionCommentParams) => {
    const {
      courseID,
      assignmentID,
      userID,
    } = this.props
    this.setState({ shouldShowStatus: true })
    this.props.makeAComment(
      courseID,
      assignmentID,
      userID,
      comment,
    )
  }

  deletePendingComment = (localID: string) => {
    this.props.deletePendingComment(
      this.props.assignmentID,
      this.props.userID,
      localID
    )
  }

  renderComment = ({ item }: { item: CommentRowProps }) =>
    <CommentRow
      {...item}
      testID={'submission-comment-' + item.key}
      style={{ transform: [{ rotate: '180deg' }] }}
      retryPendingComment={this.makeAComment}
      deletePendingComment={this.deletePendingComment}
      localID={item.key}
    />

  statusComplete = () => {
    this.setState({ shouldShowStatus: false })
  }

  render (): any {
    const rows = this.props.commentRows || []
    let hasPending = this.props.commentRows.some(c => c.pending)
    return (
      <View style={{ flex: 1 }}>
        <FlatList
          showsVerticalScrollIndicator={false}
          style={{ transform: [{ rotate: '180deg' }] }}
          data={rows}
          renderItem={this.renderComment}
        />
        { this.state.shouldShowStatus &&
          <CommentStatus
            isDone={!hasPending}
            animationComplete={this.statusComplete}
            drawerState={this.props.drawerState}
            userID={this.props.userID}
          />
        }
        <CommentInput makeComment={this.makeAComment} drawerState={this.props.drawerState} disabled={hasPending} />
      </View>
    )
  }
}

type CommentRows = { commentRows: Array<CommentRowData> }

type RoutingProps = {
  courseID: string,
  assignmentID: string,
  userID: string,
  submissionID: ?string,
  drawerState: DrawerState,
}

type Props = CommentRows & RoutingProps & CommentActions

type CommentRowData = {
  error?: string,
  style?: Object,
  key: string,
  name: string,
  date: Date,
  avatarURL: string,
  from: 'me' | 'them',
  contents: CommentContent,
  pending: number,
}

function extractComments (submission: SubmissionComments): Array<CommentRowData> {
  const session = getSession()
  const myUserID = session ? session.user.id : '😲'

  return submission.submission_comments
    .filter(comment => !comment.media_comment) // TODO don't exclmedia comments
    .map(comment => ({
      key: 'comment-' + comment.id,
      name: comment.author_name,
      date: new Date(comment.created_at),
      avatarURL: comment.author.avatar_image_url,
      from: comment.author.id === myUserID ? 'me' : 'them',
      contents: { type: 'text', message: comment.comment },
      pending: 0,
    }))
}

function contentForAttempt (attempt: Submission): Array<SubmittedContentDataProps> {
  switch (attempt.submission_type) {
    case 'online_text_entry':
      return [{
        contentID: 'text',
        icon: Images.document,
        title: textSubmission,
        subtitle: striptags(attempt.body || ''),
      }]
    case 'online_url':
      return [{
        contentID: 'url',
        icon: Images.document,
        title: urlSubmission,
        subtitle: attempt.url || '',
      }]
    case 'online_upload':
    case 'media_recording':
      const attachments = attempt.attachments || []
      return attachments.map(attachment => ({
        contentID: `attachment-${attachment.id}`,
        icon: Images.document,
        title: attachment.display_name,
        subtitle: filesize(attachment.size),
      }))
  }
  return []
}

function rowForSubmission (user: User, attempt: Submission): CommentRowData {
  const attemptNumber = attempt.attempt || 0
  const submittedAt = attempt.submitted_at || ''

  const items = contentForAttempt(attempt)
  return {
    key: `submission-${attemptNumber}`,
    name: user.name,
    avatarURL: user.avatar_url,
    from: 'them',
    date: new Date(submittedAt),
    contents: {
      type: 'submission',
      items: items,
    },
    pending: 0,
  }
}

function extractAttempts (submission: SubmissionWithHistory): Array<CommentRowData> {
  return submission.submission_history
    .map(attempt => rowForSubmission(submission.user, attempt))
}

function extractPendingComments (assignments: ?AssignmentContentState, userID): Array<CommentRowData> {
  const session = getSession()
  if (!assignments || !session) {
    return []
  }

  const pendingForStudent: Array<PendingCommentState> = assignments.pendingComments[userID] || []
  return pendingForStudent.map(pending => ({
    date: new Date(pending.timestamp),
    key: pending.localID,
    from: 'me',
    name: session.user.name,
    avatarURL: session.user.avatar_url,
    contents: pending.comment,
    pending: pending.pending,
    error: pending.error || undefined, // this fixes flow even though error could already be undefined...
  }))
}

export function mapStateToProps ({ entities }: AppState, ownProps: RoutingProps): CommentRows {
  const { submissionID, userID, assignmentID } = ownProps

  const submission = submissionID &&
    entities.submissions[submissionID]
      ? entities.submissions[submissionID].submission
      : undefined

  const assignments = entities.assignments[assignmentID]

  const pendingComments = extractPendingComments(assignments, userID)
  const comments = submission ? extractComments(submission) : []
  const attempts = submission ? extractAttempts(submission) : []

  const commentRows = [
    ...comments,
    ...attempts,
    ...pendingComments,
  ].sort((c1, c2) => c2.date.getTime() - c1.date.getTime())

  return {
    commentRows,
  }
}

const Connected = connect(
  mapStateToProps,
  SubmissionCommentActions
)(CommentsTab)

export default (Connected: any)
