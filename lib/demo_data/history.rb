module DemoData
  # Past traffic for the operations view and the release gate, so a fresh demo has something to
  # measure. Everything is invented and written directly as rows dated in the past; the live demo
  # rows (DemoData.load!) are the ones that go through the real path. History writes no audit
  # events: the audit trail records what people did, and nobody did these.
  #
  # Two parts:
  # * the demo clinic's last two weeks: check-ins answered through approved reply drafts, the
  #   model calls behind them, two answers that missed the 24-hour promise;
  # * a second invented clinic ("network") whose months of reviewed drafts give the release gate
  #   enough reviews to decide. Releases are global, so the gate pools clinics. The story it
  #   carries: check-in-reply/3 improved on /2 (pass), closing-report/2 is too new to judge
  #   (wait), and a cheaper model trialled for plan changes made reviewers reject more (block).
  module History
    module_function

    SEED = 20_261_121

    # [kind, prompt_version, model, days ago (range), reviewed, rejected, edited]
    NETWORK = [
      [ "check_in_reply", "check-in-reply/2", "simulated-1", 46..120, 180, 11, 54 ],
      [ "check_in_reply", "check-in-reply/3", "simulated-1", 1..45, 150, 6, 27 ],
      [ "closing_report", "closing-report/1", "simulated-1", 30..120, 70, 5, 28 ],
      [ "closing_report", "closing-report/2", "simulated-1", 1..29, 22, 1, 7 ],
      [ "plan_change", "plan-change/2", "simulated-1", 21..120, 90, 7, 18 ],
      [ "plan_change", "plan-change/2", "simulated-1-mini", 1..20, 60, 15, 18 ]
    ].freeze

    # p50 latency (ms), input tokens, output tokens, model calls per draft
    SHAPE = {
      "check_in_reply" => [ 2_800, 900, 260, 1 ], "closing_report" => [ 7_200, 2_300, 950, 1 ],
      "plan_change" => [ 4_100, 1_600, 320, 3 ], "check_in_screen" => [ 1_300, 520, 60, 1 ]
    }.freeze

    MESSAGES = [ "Übungen gemacht, Knie etwas steif am Morgen.", "Heute nur die Hälfte geschafft, war müde.",
                 "Schmerz wie letzte Woche, die Brücke klappt besser.", "Alles gut, ich steigere langsam.",
                 "Nach dem Gehen leichtes Ziehen in der Wade.", "Konnte zwei Tage nicht trainieren, Termin beim Hausarzt." ].freeze

    def load!(clinic, staff, today:)
      rng = Random.new(SEED)
      now = today == Date.current ? Time.current : today.in_time_zone.change(hour: 12)
      own_clinic!(clinic, staff, now, rng)
      network!(now, rng)
    end

    # --- the demo clinic's last two weeks -----------------------------------------------------

    def own_clinic!(clinic, staff, now, rng)
      enrolments = Enrolment.joins(:patient).where(patients: { clinic_id: clinic.id }, status: "active").order(:id).to_a
      return if enrolments.empty?
      return if AiDraft.where(enrolment: enrolments).where(ai_drafts: { created_at: ...(now - 1.day) }).exists?

      # hours from check-in to approved reply; two miss the 24-hour promise
      waits = [ 3, 5, 2, 9, 4, 18, 6, 27, 3, 7, 11, 2, 5, 31, 4, 8, 6, 3, 12, 5 ]
      waits.each_with_index do |wait, i|
        e = enrolments[i % enrolments.size]
        submitted = now - (13.days - (i * 15).hours) - rng.rand(0..120).minutes
        answered = submitted + wait.hours + rng.rand(0..40).minutes
        next if answered > now - 1.hour

        check_in = CheckIn.create!(enrolment: e, submitted_at: submitted, pain_score: 2 + (i % 4), message: MESSAGES[i % MESSAGES.size],
                                   status: "answered", answered_at: answered,
                                   screen: { "model" => "simulated-1", "prompt_version" => "check-in-screen/1", "added" => [], "dropped" => [],
                                             "screened_at" => (submitted + 1.minute).iso8601 },
                                   created_at: submitted, updated_at: answered)
        edited = [ 3, 8, 14 ].include?(i)
        draft = AiDraft.create!(enrolment: e, requested_by: staff[:therapist], reviewed_by: staff[:therapist], kind: "check_in_reply",
                                status: "approved", edited: edited, input_digest: "demo-history-#{check_in.id}",
                                model: "simulated-1", prompt_version: "check-in-reply/3",
                                output: { "check_in_id" => check_in.id, "reply" => "Danke für Ihre Rückmeldung. Machen Sie weiter so, in Ihrem Tempo." },
                                created_at: submitted + 2.minutes, updated_at: answered, reviewed_at: answered)
        calls(clinic.id, "check_in_screen", "check-in-screen/1", "simulated-1", submitted + 1.minute, rng)
        calls(clinic.id, "check_in_reply", "check-in-reply/3", "simulated-1", draft.created_at, rng)
      end
      # one model timeout on a reply, retried by the job
      calls(clinic.id, "check_in_reply", "check-in-reply/3", "simulated-1", now - 4.days, rng, outcome: "error")
    end

    # --- a second invented clinic, for the release gate ---------------------------------------

    def network!(now, rng)
      clinic = Clinic.find_or_create_by!(ik_number: "260999002") { |c| c.name = "Klinik am Havelufer (demo history)" }
      return if AiDraft.joins(enrolment: :patient).where(patients: { clinic_id: clinic.id }).exists?

      therapist = User.find_or_create_by!(email: "hanno@havelufer.example") do |u|
        u.assign_attributes(clinic: clinic, role: "therapist", name: "Hanno Reuter", password: DemoData::PASSWORD)
      end
      physician = User.find_or_create_by!(email: "ines@havelufer.example") do |u|
        u.assign_attributes(clinic: clinic, role: "physician", name: "Dr. Ines Albers", password: DemoData::PASSWORD)
      end
      enrolments = Array.new(12) do |i|
        patient = Patient.create!(clinic: clinic, full_name: "Rehabilitand #{i + 1} (Havelufer)", birth_date: Date.new(1950 + (i * 2), 1 + (i % 12), 10),
                                  insurance_number: format("H%02d %06d", i, 30_000 + i), rehab_ended_on: now.to_date - (130 + i).days,
                                  indication: "orthopaedics")
        CareAssignment.create!(patient: patient, therapist: therapist)
        Enrolment.create!(patient: patient, programme: "t_rena_digital")
      end

      NETWORK.each_with_index do |(kind, version, model, days, reviewed, rejected, edited), n|
        outcomes = ([ :rejected ] * rejected) + ([ :edited ] * edited) + ([ :unchanged ] * (reviewed - rejected - edited))
        outcomes.shuffle(random: rng).each_with_index do |outcome, i|
          e = enrolments[(i + n) % enrolments.size]
          created = now - rng.rand(days.begin.to_f..days.end.to_f).days
          reviewed_at = created + rng.rand(20..600).minutes
          output = {}
          if kind == "check_in_reply"
            # a rejected reply's check-in was answered by a person's own reply an hour later
            answered = outcome == :rejected ? reviewed_at + 1.hour : reviewed_at
            ci = CheckIn.create!(enrolment: e, submitted_at: created - 3.minutes, pain_score: rng.rand(1..6), message: MESSAGES[i % MESSAGES.size],
                                 status: "answered", answered_at: answered, created_at: created - 3.minutes, updated_at: answered)
            output = { "check_in_id" => ci.id }
          end
          AiDraft.create!(enrolment: e, requested_by: kind == "closing_report" ? physician : therapist, reviewed_by: therapist,
                          kind: kind, status: outcome == :rejected ? "rejected" : "approved", edited: outcome == :edited,
                          input_digest: "demo-network-#{n}-#{i}", model: model, prompt_version: version, output: output,
                          created_at: created, updated_at: reviewed_at, reviewed_at: reviewed_at)
          calls(clinic.id, kind, version, model, created, rng)
        end
      end
    end

    # --- model calls --------------------------------------------------------------------------

    def calls(clinic_id, task, version, model, at, rng, outcome: "ok")
      p50, input, output, per_draft = SHAPE.fetch(task)
      rows = Array.new(outcome == "ok" ? per_draft : 1) do |step|
        # log-normal around the median, so the 95th percentile sits at about twice the median
        latency = outcome == "ok" ? (p50 * Math.exp(0.45 * gaussian(rng))).round : 60_000
        tokens_in = (input * rng.rand(0.8..1.25)).round + (step * 400)
        tokens_out = outcome == "ok" ? (output * rng.rand(0.7..1.3)).round : 0
        { clinic_id: clinic_id, task: task, prompt_version: version, model: model, provider: "simulated", outcome: outcome,
          latency_ms: latency, input_tokens: tokens_in, output_tokens: tokens_out, tokens_estimated: true,
          cost_microeuros: Ai::Costs.microeuros(model, input_tokens: tokens_in, output_tokens: tokens_out),
          created_at: at + (step * 5).seconds }
      end
      AiCall.insert_all!(rows)
    end

    def gaussian(rng)
      Math.sqrt(-2 * Math.log(1 - rng.rand)) * Math.cos(2 * Math::PI * rng.rand)
    end
  end
end
