# What the clinic bills the DRV for one enrolment: an invoice, the participation record and the
# signed closing documentation. One claim per enrolment (unique index); its status moves only
# through Billing::ClaimLifecycle.
class Claim < ApplicationRecord
  STATUSES = %w[draft ready submitted paid rejected needs_review].freeze

  belongs_to :enrolment

  validates :status, inclusion: { in: STATUSES }
  validates :number, presence: true
  validates :amount_cents, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def amount
    format("%.2f", amount_cents / 100.0)
  end
end
