# The closing documentation sent with a claim. A physician signs it; once signed it is frozen.
class ClosingReport < ApplicationRecord
  SECTIONS = %w[course outcome adherence recommendation].freeze

  belongs_to :enrolment
  belongs_to :ai_draft, optional: true
  belongs_to :signed_by, class_name: "User", optional: true

  validate :sections_complete
  validate :frozen_once_signed, on: :update

  def signed?
    signed_at.present?
  end

  def sign!(physician)
    raise ArgumentError, "only a physician signs a closing report" unless physician.physician?

    update!(signed_by: physician, signed_at: Time.current)
  end

  private

  def sections_complete
    missing = SECTIONS.reject { |s| sections[s].to_s.strip.present? }
    errors.add(:sections, "missing #{missing.join(', ')}") if missing.any?
  end

  def frozen_once_signed
    errors.add(:base, "a signed closing report cannot change") if signed_at_was.present? && sections_changed?
  end
end
