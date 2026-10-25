# An append-only, hash-chained record of who did what. The database refuses updates and deletes;
# each event's digest covers the previous one, so a removed or edited row breaks the chain.
# Events hold identifiers and facts, never clinical free text or patient identity.
class AuditEvent < ApplicationRecord
  GENESIS = "0" * 64

  belongs_to :clinic, optional: true
  belongs_to :actor, class_name: "User", optional: true

  def readonly?
    persisted?
  end

  def self.record!(action:, actor: nil, subject: nil, data: {}, clinic: nil)
    clinic ||= clinic_of(subject) || actor&.clinic
    transaction do
      connection.execute("SELECT pg_advisory_xact_lock(#{connection.quote(4_242_001)})")
      prev = order(:id).last&.digest || GENESIS
      at = Time.current.change(usec: 0)
      payload = { action: action, actor_id: actor&.id, clinic_id: clinic&.id, subject_type: subject&.class&.name,
                  subject_id: subject&.id, data: data.as_json, created_at: at.iso8601 }
      create!(**payload.except(:data, :created_at), data: payload[:data], created_at: at,
              prev_digest: prev, digest: chain_digest(prev, payload))
    end
  end

  def self.chain_digest(prev, payload)
    OpenSSL::Digest::SHA256.hexdigest("#{prev}|#{JSON.generate(canonical(payload.as_json))}")
  end

  # JSON with keys sorted at every level: PostgreSQL's jsonb reorders keys, the digest must not care.
  def self.canonical(value)
    case value
    when Hash then value.keys.map(&:to_s).sort.to_h { |k| [ k, canonical(value[k] || value[k.to_sym]) ] }
    when Array then value.map { |v| canonical(v) }
    else value
    end
  end

  # Recomputes the chain; returns the id of the first event that does not match, or nil.
  def self.verify_chain
    prev = GENESIS
    order(:id).find_each do |e|
      payload = { action: e.action, actor_id: e.actor_id, clinic_id: e.clinic_id, subject_type: e.subject_type,
                  subject_id: e.subject_id, data: e.data, created_at: e.created_at.iso8601 }
      return e.id if e.prev_digest != prev || e.digest != chain_digest(prev, payload)

      prev = e.digest
    end
    nil
  end

  def self.clinic_of(subject)
    case subject
    when Clinic then subject
    when Patient, User then subject.clinic
    when Enrolment then subject.patient.clinic
    when Claim, ClosingReport, AiDraft then subject.enrolment.patient.clinic
    end
  end
end
