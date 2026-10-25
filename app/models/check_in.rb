# A patient's message to their therapist with a pain score. Red flags are found by rules when it
# arrives, never by a model.
class CheckIn < ApplicationRecord
  belongs_to :enrolment

  validates :pain_score, inclusion: { in: 0..10 }
  validates :message, presence: true, length: { maximum: 4000 }
  validates :status, inclusion: { in: %w[new escalated answered] }
end
