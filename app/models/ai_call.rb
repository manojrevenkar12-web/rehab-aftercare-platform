# One request to a model, as numbers: workflow, prompt version, model, latency, tokens, cost and
# outcome. Never the messages or the answer (see Ai::CallLog), so the ledger holds no health data.
class AiCall < ApplicationRecord
  OUTCOMES = %w[ok error refused].freeze

  belongs_to :clinic, optional: true

  validates :task, :model, :provider, presence: true
  validates :outcome, inclusion: { in: OUTCOMES }
end
