/* @flow */

import { createAction } from 'redux-actions'
import canvas from '../../../api/canvas-api'
import { type CreateDiscussionParameters, type UpdateDiscussionParameters } from '../../../api/canvas-api/discussions'

export let Actions: (typeof canvas) => any = (api) => ({
  createDiscussion: createAction('discussions.edit.create', (courseID: string, params: CreateDiscussionParameters) => {
    return {
      promise: api.createDiscussion(courseID, params),
      params,
      handlesError: true,
      courseID,
    }
  }),
  updateDiscussion: createAction('discussions.edit.update', (courseID: string, params: UpdateDiscussionParameters) => {
    return {
      promise: api.updateDiscussion(courseID, params),
      params,
      handlesError: true,
      courseID,
    }
  }),
  deleteDiscussion: createAction('discussions.edit.delete', (courseID: string, discussionID: string) => {
    return {
      promise: api.deleteDiscussion(courseID, discussionID),
      discussionID,
      handlesError: true,
      courseID,
    }
  }),
  deletePendingNewDiscussion: createAction('discussions.edit.deletePendingNew', (courseID: string) => ({
    courseID,
  })),
})

export default (Actions(canvas): any)
