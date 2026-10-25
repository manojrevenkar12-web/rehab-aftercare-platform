class ClosingReportPolicy < ApplicationPolicy
  def show? = treating? || administrative?
  def sign? = user.physician? && same_clinic?
end
