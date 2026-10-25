require "rails_helper"

RSpec.describe "Authorization matrix" do
  MATRIX = YAML.safe_load_file(Rails.root.join("spec/policies/authorization_matrix.yml"))
  PEOPLE = %w[therapist colleague physician billing admin patient outsider].freeze

  s = nil
  before(:all) { s = Scenario.build }
  # built once for all examples, outside the per-example transaction, so cleaned up here
  after(:all) { TestDatabase.truncate! }

  def person(s, name) = name == "patient" ? s[:patient_user] : s[name.to_sym]

  CHECKS = {
    "patient.show" => ->(s, u) { PatientPolicy.new(u, s[:patient]).show? },
    "patient.show_clinical" => ->(s, u) { PatientPolicy.new(u, s[:patient]).show_clinical? },
    "patient.update" => ->(s, u) { PatientPolicy.new(u, s[:patient]).update? },
    "enrolment.approve" => ->(s, u) { EnrolmentPolicy.new(u, s[:enrolment]).approve? },
    "enrolment.end_early" => ->(s, u) { EnrolmentPolicy.new(u, s[:enrolment]).end_early? },
    "enrolment.record_unit" => ->(s, u) { EnrolmentPolicy.new(u, s[:enrolment]).record_unit? },
    "enrolment.check_in" => ->(s, u) { EnrolmentPolicy.new(u, s[:enrolment]).check_in? },
    "check_in.show" => ->(s, u) { CheckInPolicy.new(u, CheckIn.new(enrolment: s[:enrolment])).show? },
    "draft.create.check_in_reply" => ->(s, u) { AiDraftPolicy.new(u, AiDraft.new(enrolment: s[:enrolment], kind: "check_in_reply")).create? },
    "draft.create.closing_report" => ->(s, u) { AiDraftPolicy.new(u, AiDraft.new(enrolment: s[:enrolment], kind: "closing_report")).create? },
    "draft.approve.plan_change" => ->(s, u) { AiDraftPolicy.new(u, AiDraft.new(enrolment: s[:enrolment], kind: "plan_change")).approve? },
    "draft.show" => ->(s, u) { AiDraftPolicy.new(u, AiDraft.new(enrolment: s[:enrolment], kind: "plan_change")).show? },
    "closing_report.sign" => ->(s, u) { ClosingReportPolicy.new(u, ClosingReport.new(enrolment: s[:enrolment])).sign? },
    "closing_report.show" => ->(s, u) { ClosingReportPolicy.new(u, ClosingReport.new(enrolment: s[:enrolment])).show? },
    "claim.index" => ->(s, u) { ClaimPolicy.new(u, Claim).index? },
    "claim.show" => ->(s, u) { ClaimPolicy.new(u, Claim.new(enrolment: s[:enrolment])).show? },
    "claim.submit" => ->(s, u) { ClaimPolicy.new(u, Claim.new(enrolment: s[:enrolment])).submit? },
    "audit.index" => ->(s, u) { AuditEventPolicy.new(u, AuditEvent).index? }
  }.freeze

  it "has a check for every action in the matrix, and the reverse" do
    expect(CHECKS.keys).to match_array(MATRIX.keys)
  end

  MATRIX.each do |action, allowed|
    PEOPLE.each do |name|
      expected = allowed.include?(name)
      it "#{expected ? 'lets' : 'refuses'} #{name} #{action}" do
        expect(CHECKS.fetch(action).call(s, person(s, name))).to eq(expected)
      end
    end
  end

  it "scopes lists: an unassigned therapist sees no patients, billing sees the clinic's, an outsider none" do
    expect(PatientPolicy::Scope.new(s[:colleague], Patient).resolve).to be_empty
    expect(PatientPolicy::Scope.new(s[:therapist], Patient).resolve).to eq([ s[:patient] ])
    expect(PatientPolicy::Scope.new(s[:billing], Patient).resolve).to eq([ s[:patient] ])
    expect(PatientPolicy::Scope.new(s[:outsider], Patient).resolve).to be_empty
    expect(PatientPolicy::Scope.new(s[:patient_user], Patient).resolve).to eq([ s[:patient] ])
  end
end
