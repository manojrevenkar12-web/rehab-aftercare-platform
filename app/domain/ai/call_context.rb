module Ai
  # Which clinic a model call is made for. Jobs set it around a workflow so the call ledger can be
  # read per clinic; Rails resets it after every job and request.
  class CallContext < ActiveSupport::CurrentAttributes
    attribute :clinic_id
  end
end
