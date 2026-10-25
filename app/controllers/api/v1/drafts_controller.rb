module Api
  module V1
    class DraftsController < BaseController
      def create
        enrolment = Enrolment.find(params[:enrolment_id])
        kind = params.require(:kind)
        authorize AiDraft.new(enrolment: enrolment, kind: kind)
        check_in = params[:check_in_id] && enrolment.check_ins.find(params[:check_in_id])
        draft = Care::DraftRequest.call(enrolment: enrolment, kind: kind, actor: current_user, check_in: check_in)
        render json: Presenters.draft(draft), status: draft.previously_new_record? ? :accepted : :ok
      end

      def show
        draft = AiDraft.find(params[:id])
        authorize draft
        render json: Presenters.draft(draft)
      end

      def approve
        draft = AiDraft.find(params[:id])
        authorize draft
        edits = params[:edits]&.permit(:reply, :course, :outcome, :adherence, :recommendation, changes: [ %i[action exercise_key sets reps per_week reason] ])&.to_h
        edits&.dig("changes")&.each { |c| %w[sets reps per_week].each { |k| c[k] = Integer(c[k]) if c[k] } }
        Care::DraftReview.new(draft, actor: current_user).approve!(edits: edits.presence)
        render json: Presenters.draft(draft.reload)
      end

      def reject
        draft = AiDraft.find(params[:id])
        authorize draft
        Care::DraftReview.new(draft, actor: current_user).reject!(reason: params.require(:reason))
        render json: Presenters.draft(draft.reload)
      end
    end
  end
end
