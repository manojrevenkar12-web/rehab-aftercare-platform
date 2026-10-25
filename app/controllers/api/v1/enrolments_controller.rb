module Api
  module V1
    class EnrolmentsController < BaseController
      before_action :load_enrolment

      def approve
        authorize @enrolment
        @enrolment.approve!(cost_approval_ref: params.require(:cost_approval_ref), approved_on: Date.iso8601(params.require(:approved_on)), actor: current_user)
        render json: Presenters.enrolment(@enrolment.reload, today: Date.current)
      end

      def record_unit
        authorize @enrolment
        attrs = params.require(:unit).permit(:performed_on, :duration_minutes, :pain_before, :pain_after, :effort, :note, :idempotency_key).to_h.symbolize_keys
        attrs[:performed_on] = Date.iso8601(attrs.fetch(:performed_on))
        attrs[:source] = current_user.patient? ? "patient_app" : "therapist"
        attrs[:therapist] = current_user if current_user.therapist?
        unit = @enrolment.record_unit!(attrs, actor: current_user)
        render json: { unit: Presenters.unit(unit, clinical: true), enrolment: Presenters.enrolment(@enrolment.reload, today: Date.current) }, status: :created
      end

      def end_early
        authorize @enrolment
        @enrolment.end_early!(reason: params.require(:reason), on: Date.iso8601(params.require(:on)), actor: current_user)
        render json: Presenters.enrolment(@enrolment.reload, today: Date.current)
      end

      def check_in
        authorize @enrolment
        check_in = Care::CheckInIntake.call(enrolment: @enrolment, message: params.require(:message), pain_score: Integer(params.require(:pain_score)), actor: current_user)
        render json: Presenters.check_in(check_in), status: :created
      end

      def timeline
        authorize @enrolment.patient, :show_clinical?
        audit("patient.viewed", @enrolment.patient, { clinical: true })
        render json: Presenters.timeline(@enrolment, today: Date.current, viewer: current_user)
      end

      private

      def load_enrolment
        @enrolment = Enrolment.find(params[:id])
      end
    end
  end
end
