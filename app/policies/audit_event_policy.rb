class AuditEventPolicy < ApplicationPolicy
  def index? = user.clinic_admin?

  class Scope < Scope
    def resolve
      user.clinic_admin? ? scope.where(clinic_id: user.clinic_id) : scope.none
    end
  end
end
