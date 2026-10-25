module Api
  module V1
    class AuditEventsController < BaseController
      def index
        authorize AuditEvent
        events = policy_scope(AuditEvent).order(id: :desc).limit(200)
        render json: { events: events.map { |e| Presenters.audit_event(e) }, chain_broken_at: AuditEvent.verify_chain }
      end
    end
  end
end
