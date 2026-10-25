module Billing
  # The moves a claim can make after assembly, each guarded and audited:
  #
  #   draft ──(assembler)──▶ ready ──submit──▶ submitted ──paid──▶ paid
  #                            ▲                   │
  #   needs_review ──decide────┘                   └──rejected──▶ rejected ──(fix, reassemble)──▶ ready
  class ClaimLifecycle
    class Error < StandardError; end

    def initialize(claim, actor:)
      @claim = claim
      @actor = actor
    end

    def submit!
      move!(from: %w[ready], to: "submitted", attrs: { submitted_at: Time.current })
    end

    def mark_paid!
      move!(from: %w[submitted], to: "paid", attrs: { settled_at: Time.current })
    end

    def mark_rejected!(reason:)
      raise Error, "a rejection needs a reason" if reason.blank?

      move!(from: %w[submitted], to: "rejected", attrs: { settled_at: Time.current, rejection_reason: reason })
    end

    # A person decides how an early end is billed: how many units, and why. The claim then
    # becomes ready like any other.
    def decide_review!(units:, note:)
      raise Error, "a review decision needs a note" if note.blank?

      max = @claim.enrolment.units_done
      raise Error, "units must be between 0 and #{max}" unless units.is_a?(Integer) && units.between?(0, max)

      rate = @claim.enrolment.programme_rules.rate_cents_per_unit
      docs = @claim.documents.merge("review" => { "units" => units, "note" => note, "decided_by" => @actor.id })
      move!(from: %w[needs_review], to: "ready", attrs: { units_billed: units, amount_cents: units * rate, documents: docs, problems: [] })
    end

    private

    def move!(from:, to:, attrs:)
      Claim.transaction do
        @claim.lock!
        raise Error, "claim #{@claim.number} is #{@claim.status}; cannot become #{to}" unless from.include?(@claim.status)

        before = @claim.status
        @claim.update!(attrs.merge(status: to))
        AuditEvent.record!(actor: @actor, action: "claim.#{to}", subject: @claim,
                           data: { from: before, amount_cents: @claim.amount_cents, units: @claim.units_billed })
      end
      @claim
    end
  end
end
