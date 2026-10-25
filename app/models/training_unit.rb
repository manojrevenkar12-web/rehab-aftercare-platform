# One unit of aftercare (a training session). Units are written once per idempotency key, so an
# app that retries after a timeout records the session once.
class TrainingUnit < ApplicationRecord
  SOURCES = %w[patient_app therapist].freeze

  belongs_to :enrolment
  belongs_to :therapist, class_name: "User", optional: true

  validates :performed_on, :duration_minutes, :idempotency_key, presence: true
  validates :source, inclusion: { in: SOURCES }
  validates :pain_before, :pain_after, inclusion: { in: 0..10 }, allow_nil: true
  validates :effort, inclusion: { in: 0..10 }, allow_nil: true
  validate :within_the_programme_window, on: :create

  def counts?
    duration_minutes >= enrolment.programme_rules.min_unit_minutes
  end

  private

  def within_the_programme_window
    return if enrolment.nil? || performed_on.nil?

    finish = enrolment.deadlines.latest_finish
    errors.add(:performed_on, "is after the programme's last day (#{finish})") if performed_on > finish
    errors.add(:performed_on, "is before rehab ended") if performed_on < enrolment.patient.rehab_ended_on
    errors.add(:performed_on, "is in the future") if performed_on > Date.current
  end
end
