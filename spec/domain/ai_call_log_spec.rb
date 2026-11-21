require "rails_helper"

RSpec.describe Ai::CallLog do
  let(:messages) { [ { role: "system", content: "Antworte kurz." }, { role: "user", content: JSON.generate({ "message" => "Knie schmerzt seit gestern", "pain_score" => 3 }) } ] }
  let(:provider) { Ai::Providers::Simulated.new }
  let(:clinic) { create(:clinic) }

  def reply(usage: nil) = Ai::Client::Reply.new(content: { "flags" => [] }, tool_calls: [], model: "simulated-1", usage: usage)

  it "records a call as numbers only, priced and attributed to the clinic" do
    allow(provider).to receive(:chat).and_return(reply)
    Ai::CallContext.set(clinic_id: clinic.id) do
      Ai::Client.new(provider: provider).chat(task: "check_in_screen", messages: messages, prompt_version: "check-in-screen/1")
    end
    call = AiCall.sole
    expect(call).to have_attributes(clinic_id: clinic.id, task: "check_in_screen", prompt_version: "check-in-screen/1", model: "simulated-1",
                                    provider: "simulated", outcome: "ok", tokens_estimated: true)
    expect(call.input_tokens).to eq((JSON.generate(messages).length / 4.0).ceil)
    expect(call.cost_microeuros).to eq(Ai::Costs.microeuros("simulated-1", input_tokens: call.input_tokens, output_tokens: call.output_tokens))
    expect(call.attributes.values.map(&:to_s).join).not_to include("Knie")
  end

  it "uses the tokens a provider reports" do
    allow(provider).to receive(:chat).and_return(reply(usage: { input_tokens: 1000, output_tokens: 1000 }))
    Ai::Client.new(provider: provider).chat(task: "check_in_reply", messages: messages)
    expect(AiCall.sole).to have_attributes(input_tokens: 1000, output_tokens: 1000, tokens_estimated: false, cost_microeuros: 2000)
  end

  it "records a refused request and a failed one, and still raises" do
    guard = Ai::Pseudonymizer.new(full_name: "Anna Becker")
    leaking = [ { role: "user", content: "Anna Becker hat Schmerzen" } ]
    expect { Ai::Client.new(provider: provider).chat(task: "check_in_reply", messages: leaking, guard: guard) }.to raise_error(Ai::Client::LeakRefused)
    allow(provider).to receive(:chat).and_raise(Ai::Providers::OpenAiCompatible::Error, "HTTP 503")
    expect { Ai::Client.new(provider: provider).chat(task: "check_in_reply", messages: messages) }.to raise_error(Ai::Providers::OpenAiCompatible::Error)
    expect(AiCall.order(:id).pluck(:outcome)).to eq(%w[refused error])
  end

  it "records nothing when logging is off, as in the offline evaluation" do
    Ai::Client.new(provider: provider, log: nil).chat(task: "check_in_screen", messages: messages)
    expect(AiCall.count).to eq(0)
  end

  it "never fails the call when the ledger cannot be written" do
    allow(AiCall).to receive(:create!).and_raise(ActiveRecord::StatementInvalid, "db down")
    expect(Ai::Client.new(provider: provider).chat(task: "check_in_screen", messages: messages).content).to eq({ "flags" => [] })
  end

  it "prices by the longest matching model prefix and flags unknown models" do
    expect(Ai::Costs.microeuros("simulated-1-mini", input_tokens: 1000, output_tokens: 1000)).to eq(750)
    expect(Ai::Costs.microeuros("simulated-1", input_tokens: 1000, output_tokens: 1000)).to eq(2000)
    expect(Ai::Costs.priced?("eu-model-x")).to be(false)
  end
end
