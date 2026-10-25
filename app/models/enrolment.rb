# A patient's place in one DRV aftercare programme. Status changes only through the methods below,
# each of which checks the programme's rules and writes an audit event.
class Enrolment < ApplicationRecord
  STATUSES = %w[referred approved active completed ended_early expired].freeze
  END_REASONS = %w[patient_withdrew goal_unreachable medical_reasons start_missed finish_missed].freeze

  class TransitionError < StandardError; end

  belongs_to :patient
  has_many :training_units, dependent: :restrict_with_exception
  has_many :check_ins, dependent: :restrict_with_exception
  has_many :ai_drafts, dependent: :restrict_with_exception
  has_many :plan_items, dependent: :destroy
  has_one :closing_report, dependent: :restrict_with_exception
  has_one :claim, dependent: :restrict_with_exception

  validates :status, inclusion: { in: STATUSES }
  validates :programme, inclusion: { in: ->(_) { Aftercare::Programmes.keys } }
  validates :end_reason, inclusion: { in: END_REASONS }, allow_nil: true

  before_validation :set_units_required, on: :create

  def programme_rules
    Aftercare::Programmes.fetch(programme)
  end

  def deadlines
    Aftercare::DeadlineCheck.new(
      rehab_ended_on: patient.rehab_ended_on,
      status: status,
      started_on: started_on,
      unit_dates: training_units.pluck(:performed_on)
    )
  end

  def counted_units
    training_units.select(&:counts?)
  end

  def units_done
    counted_units.size
  end

  def finished?
    %w[completed ended_early expired].include?(status)
  end

  # --- transitions -----------------------------------------------------------------------------

  def approve!(cost_approval_ref:, approved_on:, actor:)
    transition!(from: %w[referred], to: "approved", actor: actor,
                attrs: { cost_approval_ref: cost_approval_ref, approved_on: approved_on })
  end

  # Records a unit (idempotently) and moves the enrolment along: the first unit starts it, the last
  # required one completes it.
  def record_unit!(attrs, actor:)
    with_lock do
      raise TransitionError, "cannot record units while #{status}" unless %w[approved active].include?(status)

      existing = training_units.find_by(idempotency_key: attrs.fetch(:idempotency_key))
      return existing if existing

      check = deadlines
      day = attrs.fetch(:performed_on).to_date
      if status == "approved" && day > check.latest_start
        raise TransitionError, "the programme had to start by #{check.latest_start}"
      end

      unit = training_units.create!(attrs)
      if status == "approved"
        update!(status: "active", started_on: day)
        AuditEvent.record!(actor: actor, action: "enrolment.started", subject: self, data: { on: day })
      end
      AuditEvent.record!(actor: actor, action: "unit.recorded", subject: self,
                         data: { unit_id: unit.id, performed_on: day, minutes: unit.duration_minutes, counts: unit.counts? })
      complete!(on: day, actor: actor) if units_done >= units_required
      unit
    end
  end

  def end_early!(reason:, on:, actor:)
    raise TransitionError, "unknown end reason #{reason}" unless END_REASONS.include?(reason)

    transition!(from: %w[approved active], to: "ended_early", actor: actor, attrs: { ended_on: on, end_reason: reason })
  end

  # Applies the time rules that end an enrolment by themselves; the break rule is not one of them,
  # because the DRV leaves that judgement to the therapist.
  def apply_deadlines!(today:, actor: nil)
    codes = deadlines.findings(today).map(&:code)
    if codes.include?(:start_missed)
      transition!(from: %w[referred approved], to: "expired", actor: actor, attrs: { ended_on: today, end_reason: "start_missed" })
    elsif codes.include?(:finish_missed)
      transition!(from: %w[active], to: "expired", actor: actor, attrs: { ended_on: today, end_reason: "finish_missed" })
    end
  end

  private

  def complete!(on:, actor:)
    update!(status: "completed", completed_on: on)
    AuditEvent.record!(actor: actor, action: "enrolment.completed", subject: self, data: { on: on, units: units_done })
  end

  def transition!(from:, to:, actor:, attrs: {})
    with_lock do
      raise TransitionError, "cannot go from #{status} to #{to}" unless from.include?(status)

      before = status
      update!(attrs.merge(status: to))
      AuditEvent.record!(actor: actor, action: "enrolment.#{to}", subject: self, data: attrs.merge(from: before))
    end
    self
  end

  def set_units_required
    self.units_required ||= programme_rules.units_for(patient&.indication) if programme.present?
  rescue KeyError
    nil
  end
end
