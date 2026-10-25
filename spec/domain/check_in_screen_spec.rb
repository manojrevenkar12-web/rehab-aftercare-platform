require "rails_helper"

RSpec.describe Ai::Workflows::CheckInScreen do
  # A provider that answers the screen with whatever the test says.
  def screen_with(content, message: "Mir ist so eng ums Herz und die Luft bleibt weg", already: [])
    provider = Ai::Providers::Simulated.new
    allow(provider).to receive(:chat).and_return(Ai::Client::Reply.new(content: content, tool_calls: [], model: "test-model"))
    described_class.new(client: Ai::Client.new(provider: provider)).call({ "message" => message, "already_flagged" => already })
  end

  it "adds a flag the model quotes from the message" do
    out = screen_with({ "flags" => [ { "code" => "breathlessness", "quote" => "die Luft bleibt weg" } ] })
    expect(out.added).to eq([ { "code" => "breathlessness", "severity" => "emergency", "evidence" => "die Luft bleibt weg", "source" => "model" } ])
    expect(out.dropped).to be_empty
  end

  it "drops a flag whose quote is not the patient's words, and an unknown flag" do
    out = screen_with({ "flags" => [ { "code" => "chest_pain", "quote" => "crushing chest pain" }, { "code" => "dizziness", "quote" => "Mir ist so" } ] })
    expect(out.added).to be_empty
    expect(out.dropped.pluck("reason")).to eq([ "quote not in the message", "unknown flag" ])
  end

  it "cannot remove what the rules found, and adds nothing twice" do
    out = screen_with({ "flags" => [ { "code" => "fall", "quote" => "Luft bleibt weg" } ], "remove" => [ "fall" ] }, already: [ "fall" ])
    expect(out.added).to be_empty
  end

  it "fails safe: a broken answer adds nothing and says why" do
    out = screen_with("not json")
    expect(out.added).to be_empty
    expect(out.error).to include("JSON")
  end
end

RSpec.describe ScreenCheckInJob do
  include ActiveJob::TestHelper
  let(:s) { Scenario.build }
  let(:e) { s[:enrolment] }

  it "escalates a check-in the model adds a flag to, and records what it did" do
    ci = e.check_ins.create!(message: "Mir ist so eng ums Herz", pain_score: 3, submitted_at: Time.current, red_flags: [], status: "new")
    provider = Ai::Providers::Simulated.new
    allow(provider).to receive(:chat).and_return(Ai::Client::Reply.new(content: { "flags" => [ { "code" => "chest_pain", "quote" => "eng ums Herz" } ] }, tool_calls: [], model: "test-model"))
    described_class.perform_now(ci.id, client: Ai::Client.new(provider: provider))
    expect(ci.reload).to have_attributes(status: "escalated")
    expect(ci.red_flags.pluck("code", "source")).to eq([ %w[chest_pain model] ])
    expect(ci.screen).to include("model" => "test-model", "added" => [ "chest_pain" ])
    expect(AuditEvent.where(action: "check_in.escalated_by_screen").count).to eq(1)
  end

  it "leaves the rules' result alone when the model is unavailable" do
    ci = e.check_ins.create!(message: "Bin gestürzt", pain_score: 3, submitted_at: Time.current, red_flags: [ { "code" => "fall", "severity" => "urgent", "evidence" => "gestürzt" } ], status: "escalated")
    provider = Ai::Providers::Simulated.new
    allow(provider).to receive(:chat).and_raise(Ai::Providers::OpenAiCompatible::Error, "timeout")
    described_class.perform_now(ci.id, client: Ai::Client.new(provider: provider))
    expect(ci.reload.red_flags.pluck("code")).to eq([ "fall" ])
    expect(ci.screen["error"]).to include("timeout")
  end
end
