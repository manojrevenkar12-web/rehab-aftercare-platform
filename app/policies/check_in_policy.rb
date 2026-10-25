class CheckInPolicy < ApplicationPolicy
  def show? = treating? || own?
  def create? = own?
end
