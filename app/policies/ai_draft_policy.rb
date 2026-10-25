class AiDraftPolicy < ApplicationPolicy
  # Replies and plan changes belong to the assigned therapist; closing documentation also to the
  # physicians who sign it.
  def create? = record.kind == "closing_report" ? treating? : assigned?
  def show? = treating?
  def approve? = create?
  def reject? = create?
end
