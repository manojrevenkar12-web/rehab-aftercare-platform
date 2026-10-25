module Api
  module V1
    class SessionsController < BaseController
      skip_before_action :authenticate!, only: :create
      skip_after_action :verify_authorized

      # Rate limited per IP: password guessing gets ten tries a minute.
      rate_limit to: 10, within: 1.minute, only: :create, with: -> { error(:too_many_requests, "Too many attempts; wait a minute.") }

      def create
        user = User.find_by(email: params.require(:email).to_s.strip.downcase)
        if user&.authenticate(params.require(:password))
          _token, raw = ApiToken.issue(user)
          AuditEvent.record!(actor: user, action: "session.created", subject: user)
          render json: { token: raw, user: Presenters.user(user) }, status: :created
        else
          error(:unauthorized, "Wrong e-mail or password.")
        end
      end

      def destroy
        raw = request.authorization.to_s[/\ABearer (.+)\z/, 1]
        ApiToken.find_by(token_digest: ApiToken.digest(raw))&.revoke!
        head :no_content
      end

      def show
        render json: { user: Presenters.user(current_user) }
      end
    end
  end
end
