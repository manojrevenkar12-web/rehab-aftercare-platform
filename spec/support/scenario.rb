# A clinic with its people and one patient in T-RENA digital, for request and policy specs.
module Scenario
  def self.build
    clinic = FactoryBot.create(:clinic)
    other = FactoryBot.create(:clinic)
    therapist = FactoryBot.create(:user, :therapist, clinic: clinic, name: "Theo Therapist")
    colleague = FactoryBot.create(:user, :therapist, clinic: clinic, name: "Cleo Colleague")
    physician = FactoryBot.create(:user, :physician, clinic: clinic, name: "Dr. Petra Arzt")
    billing = FactoryBot.create(:user, :billing, clinic: clinic, name: "Bea Billing")
    admin = FactoryBot.create(:user, :clinic_admin, clinic: clinic, name: "Ada Admin")
    patient_user = FactoryBot.create(:user, :patient, clinic: clinic, name: "Anna Becker")
    patient = FactoryBot.create(:patient, clinic: clinic, user: patient_user)
    CareAssignment.create!(patient: patient, therapist: therapist)
    enrolment = FactoryBot.create(:enrolment, :approved, patient: patient)
    outsider = FactoryBot.create(:user, :physician, clinic: other, name: "Otto Outside")
    { clinic:, therapist:, colleague:, physician:, billing:, admin:, patient_user:, patient:, enrolment:, outsider: }
  end
end
