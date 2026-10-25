class PatientPolicy < ApplicationPolicy
  def index? = !user.patient?
  def show? = treating? || administrative? || own?
  # Clinical detail: units with notes, check-ins, drafts.
  def show_clinical? = treating? || own?
  def create? = user.clinic_admin?
  def update? = user.clinic_admin? && same_clinic?
  def assign? = user.clinic_admin? && same_clinic?

  class Scope < Scope
    def resolve
      case user.role
      when "clinic_admin", "billing", "physician" then scope.where(clinic_id: user.clinic_id)
      when "therapist" then scope.where(clinic_id: user.clinic_id, id: user.assigned_patient_ids)
      when "patient" then scope.where(user_id: user.id)
      else scope.none
      end
    end
  end
end
