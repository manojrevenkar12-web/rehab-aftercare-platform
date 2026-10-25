module Api
  module V1
    # The list a therapist starts the day with: their patients, ordered by what needs attention.
    class CaseloadController < BaseController
      def index
        authorize Patient, :index?
        today = Date.current
        patients = policy_scope(Patient).includes(enrolments: %i[training_units check_ins claim])
        rows = patients.map { |p| Presenters.caseload_row(p, today, clinical: PatientPolicy.new(current_user, p).show_clinical?) }
        render json: { patients: rows.sort_by { |r| [ -r[:attention], r[:pseudonym] ] }, today: today }
      end
    end
  end
end
