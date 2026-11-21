# The operations view: counts, rates, times and costs for the user's own clinic, plus the state of
# the shared job queue and release decisions. No patient appears in it, but it is still the
# clinic's business, so only its administrator sees it.
class OpsPolicy < ApplicationPolicy
  def show? = user.clinic_admin?
end
