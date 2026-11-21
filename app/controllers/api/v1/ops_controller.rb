module Api
  module V1
    # GET /api/v1/ops: the operations snapshot for the signed-in administrator's clinic.
    class OpsController < BaseController
      def show
        authorize :ops, :show?
        render json: Ops::Snapshot.new(current_user.clinic).to_h
      end
    end
  end
end
