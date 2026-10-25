# A bearer token. Only its SHA-256 digest is stored; the token itself is shown once.
class ApiToken < ApplicationRecord
  belongs_to :user

  TTL = 12.hours

  scope :live, -> { where(revoked_at: nil).where("expires_at > ?", Time.current) }

  def self.issue(user, ttl: TTL)
    raw = SecureRandom.urlsafe_base64(32)
    token = create!(user: user, token_digest: digest(raw), expires_at: ttl.from_now)
    [token, raw]
  end

  def self.authenticate(raw)
    return nil if raw.blank?

    token = live.find_by(token_digest: digest(raw))
    token&.touch(:last_used_at)
    token&.user
  end

  def self.digest(raw)
    OpenSSL::Digest::SHA256.hexdigest(raw)
  end

  def revoke!
    update!(revoked_at: Time.current)
  end
end
