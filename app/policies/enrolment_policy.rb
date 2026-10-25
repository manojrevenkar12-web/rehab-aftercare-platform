class EnrolmentPolicy < ApplicationPolicy
  def show? = PatientPolicy.new(user, record.patient).show?
  def create? = user.clinic_admin? && same_clinic?
  # Recording the DRV's cost approval is administrative work.
  def approve? = administrative?
  def end_early? = treating?
  def record_unit? = assigned? || own?
  def check_in? = own?
end
