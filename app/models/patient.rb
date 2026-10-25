# A rehabilitand. Identity (name, birth date, insurance number, contact) never leaves the
# application: jobs, logs and models see only the pseudonym.
class Patient < ApplicationRecord
  INDICATIONS = %w[orthopaedics neurology cardiology obesity psychosomatics].freeze
  IDENTITY = %i[full_name birth_date insurance_number phone email].freeze

  belongs_to :clinic
  belongs_to :user, optional: true
  has_many :care_assignments, dependent: :destroy
  has_many :therapists, -> { where(care_assignments: { active: true }) }, through: :care_assignments
  has_many :enrolments, dependent: :restrict_with_exception

  validates :full_name, :birth_date, :insurance_number, :rehab_ended_on, presence: true
  validates :indication, inclusion: { in: INDICATIONS }
  validates :insurance_number, uniqueness: { scope: :clinic_id }

  before_validation :assign_pseudonym, on: :create

  def current_enrolment
    enrolments.order(created_at: :desc).first
  end

  def identity
    IDENTITY.index_with { |k| public_send(k) }.compact
  end

  private

  def assign_pseudonym
    self.pseudonym ||= "P-#{SecureRandom.alphanumeric(8).upcase}"
  end
end
