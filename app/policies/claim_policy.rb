class ClaimPolicy < ApplicationPolicy
  def index? = user.billing? || user.clinic_admin?
  def show? = administrative?
  def assemble? = user.billing? && same_clinic?
  def submit? = assemble?
  def settle? = assemble?
  def decide_review? = assemble?

  class Scope < Scope
    def resolve
      return scope.none unless user.billing? || user.clinic_admin?

      scope.joins(enrolment: :patient).where(patients: { clinic_id: user.clinic_id })
    end
  end
end
