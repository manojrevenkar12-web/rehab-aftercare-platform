class CareAssignment < ApplicationRecord
  belongs_to :patient
  belongs_to :therapist, class_name: "User"

  validate :therapist_is_a_therapist_of_the_clinic

  private

  def therapist_is_a_therapist_of_the_clinic
    return if therapist.nil? || patient.nil?

    errors.add(:therapist, "must be a therapist") unless therapist.therapist?
    errors.add(:therapist, "must belong to the patient's clinic") unless therapist.clinic_id == patient.clinic_id
  end
end
