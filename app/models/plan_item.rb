class PlanItem < ApplicationRecord
  belongs_to :enrolment
  belongs_to :exercise

  validates :sets, :reps, :per_week, numericality: { only_integer: true, greater_than: 0 }
end
