module Api
  module V1
    class ClosingReportsController < BaseController
      def sign
        report = Enrolment.find(params[:enrolment_id]).closing_report || raise(ActiveRecord::RecordNotFound)
        authorize report
        raise Enrolment::TransitionError, "already signed" if report.signed?

        report.sign!(current_user)
        audit("closing_report.signed", report)
        render json: Presenters.closing_report(report)
      end
    end
  end
end
