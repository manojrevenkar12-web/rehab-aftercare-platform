# JSON shapes for the API. Clinical detail (notes, check-in messages, drafts) appears only when
# the caller is allowed to see it; identity appears only to the people who work with the patient.
module Presenters
  module_function

  def user(u)
    { id: u.id, name: u.name, email: u.email, role: u.role, clinic: u.clinic.name }
  end

  def caseload_row(patient, today, clinical:)
    e = patient.enrolments.max_by(&:created_at)
    findings = e ? e.deadlines.findings(today) : []
    open_flags = clinical && e ? e.check_ins.select { |c| c.status == "escalated" } : []
    attention = (findings.map { |f| { blocking: 3, urgent: 2, notice: 1 }.fetch(f.severity, 0) }.max || 0) + (open_flags.any? ? 4 : 0)
    {
      id: patient.id,
      pseudonym: patient.pseudonym,
      name: patient.full_name,
      indication: patient.indication,
      rehab_ended_on: patient.rehab_ended_on,
      enrolment: e && enrolment(e, today: today),
      escalations: open_flags.size,
      attention: attention
    }
  end

  def patient(p, clinical:, today:)
    base = {
      id: p.id, pseudonym: p.pseudonym, name: p.full_name, indication: p.indication,
      rehab_ended_on: p.rehab_ended_on, enrolments: p.enrolments.order(:created_at).map { |e| enrolment(e, today: today) }
    }
    return base unless clinical

    base.merge(birth_date: p.birth_date, insurance_number: p.insurance_number, phone: p.phone, email: p.email,
               therapists: p.therapists.map { |t| { id: t.id, name: t.name } })
  end

  def enrolment(e, today:)
    rules = e.programme_rules
    check = e.deadlines
    {
      id: e.id, programme: e.programme, programme_name: rules.name, status: e.status,
      units_done: e.units_done, units_required: e.units_required, unit_minutes: rules.unit_minutes,
      cost_approval_ref: e.cost_approval_ref, started_on: e.started_on, completed_on: e.completed_on,
      ended_on: e.ended_on, end_reason: e.end_reason,
      ideal_start: check.ideal_start, latest_start: check.latest_start, latest_finish: check.latest_finish,
      deadlines: check.findings(today).map(&:to_h),
      claim_status: e.claim&.status
    }
  end

  def unit(u, clinical:)
    base = { id: u.id, performed_on: u.performed_on, duration_minutes: u.duration_minutes, source: u.source, counts: u.counts? }
    clinical ? base.merge(pain_before: u.pain_before, pain_after: u.pain_after, effort: u.effort, note: u.note) : base
  end

  def check_in(c)
    { id: c.id, submitted_at: c.submitted_at, pain_score: c.pain_score, message: c.message, status: c.status, red_flags: c.red_flags,
      set_aside: c.set_aside }
  end

  def timeline(e, today:, viewer:)
    {
      enrolment: enrolment(e, today: today),
      patient: { id: e.patient.id, pseudonym: e.patient.pseudonym, name: e.patient.full_name, indication: e.patient.indication },
      units: e.training_units.order(:performed_on).map { |u| unit(u, clinical: true) },
      check_ins: e.check_ins.order(submitted_at: :desc).map { |c| check_in(c) },
      drafts: AiDraftPolicy.new(viewer, e.ai_drafts.new).show? ? e.ai_drafts.order(created_at: :desc).map { |d| draft(d) } : [],
      plan: e.plan_items.where(active: true).includes(:exercise).map { |i| { exercise_key: i.exercise.key, name: i.exercise.name, level: i.exercise.level, sets: i.sets, reps: i.reps, per_week: i.per_week } },
      closing_report: e.closing_report && closing_report(e.closing_report)
    }
  end

  def draft(d)
    output = d.output
    if d.kind == "check_in_reply" && output["reply"]
      output = output.merge("reply" => Ai::Pseudonymizer.new(d.enrolment.patient.identity).restore(output["reply"]))
    end
    { id: d.id, kind: d.kind, status: d.status, model: d.model, prompt_version: d.prompt_version, output: output,
      findings: d.findings, error: d.error, created_at: d.created_at, reviewed_at: d.reviewed_at,
      reviewed_by: d.reviewed_by&.name }
  end

  def closing_report(r)
    { id: r.id, sections: r.sections, signed: r.signed?, signed_at: r.signed_at, signed_by: r.signed_by&.name, from_draft: r.ai_draft_id }
  end

  def claim(c, detail: false)
    base = { id: c.id, number: c.number, status: c.status, amount: c.amount, currency: c.currency,
             units_billed: c.units_billed, patient: c.enrolment.patient.pseudonym, programme: c.enrolment.programme,
             enrolment_id: c.enrolment_id, problems: c.problems, updated_at: c.updated_at }
    detail ? base.merge(documents: c.documents, submitted_at: c.submitted_at, settled_at: c.settled_at, rejection_reason: c.rejection_reason) : base
  end

  def audit_event(e)
    { id: e.id, action: e.action, actor: e.actor&.name, subject: e.subject_type && "#{e.subject_type}##{e.subject_id}",
      data: e.data, at: e.created_at, digest: e.digest[0, 12] }
  end
end
