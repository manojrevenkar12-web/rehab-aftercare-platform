module Api
  module V1
    class PatientsController < BaseController
      def show
        patient = Patient.find(params[:id])
        authorize patient
        clinical = PatientPolicy.new(current_user, patient).show_clinical?
        audit("patient.viewed", patient, { clinical: clinical })
        render json: Presenters.patient(patient, clinical: clinical, today: Date.current)
      end
    end
  end
end
