# Daily: applies the DRV time rules that end an enrolment by themselves (start missed, finish
# missed). Breaks are left to therapists and shown in the caseload instead.
class DeadlineScanJob < ApplicationJob
  queue_as :default

  def perform(today = Date.current)
    Enrolment.where(status: %w[referred approved active]).includes(:patient, :training_units).find_each do |e|
      e.apply_deadlines!(today: today)
    rescue Enrolment::TransitionError
      next
    end
  end
end
