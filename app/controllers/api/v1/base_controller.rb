module Api
  module V1
    # Bearer-token authentication, Pundit authorisation on every action, and one JSON error shape.
    class BaseController < ApplicationController
      include Pundit::Authorization

      before_action :authenticate!
      after_action :verify_authorized

      rescue_from Pundit::NotAuthorizedError, with: -> { error(:forbidden, "You are not allowed to do this.") }
      rescue_from ActiveRecord::RecordNotFound, with: -> { error(:not_found, "Not found.") }
      rescue_from ActiveRecord::RecordInvalid, with: ->(e) { error(:unprocessable_content, e.record.errors.full_messages.to_sentence) }
      rescue_from ActionController::ParameterMissing, with: ->(e) { error(:unprocessable_content, e.message) }
      rescue_from Enrolment::TransitionError, Billing::ClaimLifecycle::Error, Care::DraftReview::Refused,
                  with: ->(e) { error(:conflict, e.message) }

      attr_reader :current_user

      private

      def pundit_user = current_user

      def authenticate!
        raw = request.authorization.to_s[/\ABearer (.+)\z/, 1]
        @current_user = ApiToken.authenticate(raw)
        error(:unauthorized, "Sign in first.") unless @current_user
      end

      def error(status, message)
        render json: { error: message }, status: status
      end

      def audit(action, subject, data = {})
        AuditEvent.record!(actor: current_user, action: action, subject: subject, data: data)
      end
    end
  end
end
