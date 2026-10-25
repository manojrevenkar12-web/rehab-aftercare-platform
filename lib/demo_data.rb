# Synthetic demo data for development and screenshots: one clinic, its staff and a handful of
# invented patients at different points of their aftercare. Nothing here is a real person.
module DemoData
  PASSWORD = "demo-password-1"

  module_function

  def load!(today: Date.current)
    clinic = Clinic.find_or_create_by!(ik_number: "260999001") { |c| c.name = "Reha-Zentrum Spreebogen (demo)" }
    staff = {
      therapist: user(clinic, "therapist", "Theo Brandt", "theo@demo.example"),
      physician: user(clinic, "physician", "Dr. Petra Lindqvist", "petra@demo.example"),
      billing: user(clinic, "billing", "Bea Kowalski", "bea@demo.example"),
      admin: user(clinic, "clinic_admin", "Ada Nowak", "ada@demo.example")
    }
    library = Exercise.all.index_by(&:key)
    people = [
      [ "Anna Becker", "orthopaedics", 80, 14, %w[pelvic_tilt bridging], [ 6, 4 ], "Seit gestern Druck auf der Brust beim Training.", 4 ],
      [ "Jürgen Haas", "orthopaedics", 120, 18, %w[quad_sets heel_slides], [ 5, 2 ], nil, nil ],
      [ "Fatma Yilmaz", "neurology", 60, 9, %w[sit_to_stand tandem_stance], [ 4, 3 ], "Ich bin gestern im Flur gestürzt, nichts gebrochen.", 5 ],
      [ "Olaf Krüger", "cardiology", 50, 3, %w[walking_intervals], [ 3, 3 ], nil, nil ],
      [ "Maria Lange", "orthopaedics", 30, 0, [], nil, nil, nil ],
      [ "Peter Schmidt", "orthopaedics", 100, 6, %w[pendulum wall_slides], [ 4, 3 ], "Alles gut, die Schulter wird beweglicher.", 2 ]
    ]
    people.each_with_index do |(name, indication, ago, units, plan, pain, message, score), i|
      patient = Patient.find_or_initialize_by(clinic: clinic, insurance_number: format("%02d %06d %s %02d %d", 12 + i, 10_165 + i, name[0], i, i))
      next if patient.persisted?

      patient.update!(full_name: name, birth_date: Date.new(1955 + (i * 4), 1 + i, 3 + i), rehab_ended_on: today - ago.days,
                      indication: indication, phone: "+49 30 555 01#{i}", email: "#{name.split.first.downcase}@patient.example")
      CareAssignment.create!(patient: patient, therapist: staff[:therapist])
      programme = indication == "orthopaedics" ? "t_rena_digital" : "irena_digital"
      e = Enrolment.create!(patient: patient, programme: programme)
      e.approve!(cost_approval_ref: "G4802-#{today.year}-#{1000 + i}", approved_on: patient.rehab_ended_on + 5.days, actor: staff[:billing])
      plan.each { |k| e.plan_items.create!(exercise: library.fetch(k), sets: 2, reps: 10, per_week: 3) }
      units.times do |n|
        day = [ patient.rehab_ended_on + 14.days + (n * 4).days, today ].min
        before, after = pain
        e.record_unit!({ performed_on: day, duration_minutes: e.programme_rules.unit_minutes, source: n.even? ? "patient_app" : "therapist",
                         pain_before: [ before - (n / 5), 0 ].max, pain_after: [ after - (n / 6), 0 ].max, effort: 4 + (n % 3),
                         idempotency_key: "demo-#{i}-#{n}" }, actor: staff[:therapist])
      end
      Care::CheckInIntake.call(enrolment: e, message: message, pain_score: score, actor: patient.user || staff[:therapist], at: today.to_time - 3.hours) if message
    end
    finish_one!(clinic, staff)
    staff
  end

  def user(clinic, role, name, email)
    User.find_or_create_by!(email: email) { |u| u.assign_attributes(clinic: clinic, role: role, name: name, password: PASSWORD) }
  end

  # Jürgen Haas completed T-RENA: draft his closing report, sign it, and bill it.
  def finish_one!(clinic, staff)
    e = Enrolment.joins(:patient).find_by(patients: { full_name: "Jürgen Haas", clinic_id: clinic.id })
    return unless e&.status == "completed" && e.closing_report.nil?

    draft = Care::DraftRequest.call(enrolment: e, kind: "closing_report", actor: staff[:physician])
    GenerateDraftJob.perform_now(draft.id)
    Care::DraftReview.new(draft.reload, actor: staff[:therapist]).approve!
    e.reload.closing_report.sign!(staff[:physician])
    claim = Billing::ClaimAssembler.call(e.reload, actor: staff[:billing])
    Billing::ClaimLifecycle.new(claim, actor: staff[:billing]).submit! if claim.status == "ready"
  end
end
