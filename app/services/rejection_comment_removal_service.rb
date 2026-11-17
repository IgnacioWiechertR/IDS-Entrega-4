# C9: the profesor who rejected the grades of an evaluation deletes the comment of that rejection. A rejected grade
# always needs a comment (C6), so deleting it withdraws the rejection: the grades go back to `pendiente`, without
# comment or reviewer, and the profesor can approve them or reject them again. Returns how many grades changed.
class RejectionCommentRemovalService
  def initialize(grade:)
    @grade = grade
  end

  def call
    RejectionCommentUpdateService.rejection_of(@grade)
      .update_all(status: "pendiente", rejection_comment: nil, reviewed_by_id: nil, updated_at: Time.current)
  end
end
