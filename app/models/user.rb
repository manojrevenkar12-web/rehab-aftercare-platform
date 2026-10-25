class User < ApplicationRecord
  ROLES = %w[clinic_admin physician therapist billing patient].freeze

  has_secure_password
  belongs_to :clinic
  has_many :api_tokens, dependent: :destroy
  has_many :care_assignments, foreign_key: :therapist_id, inverse_of: :therapist, dependent: :destroy
  has_one :patient_record, class_name: "Patient", inverse_of: :user, dependent: :nullify

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }

  normalizes :email, with: ->(e) { e.strip.downcase }

  ROLES.each { |r| define_method(:"#{r}?") { role == r } }

  def clinical?
    physician? || therapist?
  end

  # Patients this user may see in clinical detail.
  def assigned_patient_ids
    care_assignments.where(active: true).select(:patient_id)
  end
end
