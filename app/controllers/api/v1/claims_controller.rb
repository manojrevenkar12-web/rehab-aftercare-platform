module Api
  module V1
    class ClaimsController < BaseController
      def index
        authorize Claim
        claims = policy_scope(Claim).includes(enrolment: :patient).order(updated_at: :desc)
        render json: { claims: claims.map { |c| Presenters.claim(c) } }
      end

      def show
        claim = Claim.find(params[:id])
        authorize claim
        render json: Presenters.claim(claim, detail: true)
      end

      def assemble
        enrolment = Enrolment.find(params[:enrolment_id])
        authorize(enrolment.claim || Claim.new(enrolment: enrolment))
        claim = Billing::ClaimAssembler.call(enrolment, actor: current_user)
        render json: Presenters.claim(claim, detail: true)
      end

      def submit = move { |life| life.submit! }
      def paid = move(:settle?) { |life| life.mark_paid! }
      def rejected = move(:settle?) { |life| life.mark_rejected!(reason: params.require(:reason)) }
      def review = move(:decide_review?) { |life| life.decide_review!(units: Integer(params.require(:units)), note: params.require(:note)) }

      private

      def move(query = :submit?)
        claim = Claim.find(params[:id])
        authorize claim, query
        yield Billing::ClaimLifecycle.new(claim, actor: current_user)
        render json: Presenters.claim(claim.reload, detail: true)
      end
    end
  end
end
