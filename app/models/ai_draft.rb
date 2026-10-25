# A model's draft for a person to review: a reply to a check-in, closing documentation, or a change
# to the training plan. A draft never acts by itself: approval by a person is what applies it.
class AiDraft < ApplicationRecord
  KINDS = %w[check_in_reply closing_report plan_change].freeze
  STATUSES = %w[queued ready held failed approved rejected].freeze

  belongs_to :enrolment
  belongs_to :requested_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :kind, inclusion: { in: KINDS }
  validates :status, inclusion: { in: STATUSES }

  def blocking_findings
    findings.select { |f| f["severity"] == "blocking" }
  end
end
