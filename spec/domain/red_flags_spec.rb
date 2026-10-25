require "rails_helper"

RSpec.describe Ai::RedFlags do
  def codes(msg, **kw) = described_class.find(message: msg, **kw).map(&:code)

  it "finds flags in German and English, with the words that triggered them" do
    flags = described_class.find(message: "Seit gestern habe ich Druck auf der Brust und bin kurzatmig.")
    expect(flags.map(&:code)).to eq(%w[chest_pain breathlessness])
    expect(flags.first.evidence).to eq("Druck auf der Brust")
    expect(codes("I fell in the bathroom this morning")).to eq(%w[fall])
    expect(codes("Mein linkes Bein ist taub")).to eq(%w[neurological])
  end

  it "respects a negation in the same clause only" do
    expect(codes("Keine Brustschmerzen, alles gut.")).to be_empty
    expect(codes("Keine Brustschmerzen, aber Atemnot beim Treppensteigen.")).to eq(%w[breathlessness])
    expect(codes("No chest pain but I feel numb in my left arm")).to eq(%w[neurological])
    expect(codes("Ich bin nicht gestürzt")).to be_empty
  end

  it "treats a high pain score, or a jump, as a flag of its own" do
    expect(codes("ok", pain_score: 8)).to eq(%w[severe_pain])
    expect(codes("ok", pain_score: 6, previous_pain_score: 3)).to eq(%w[pain_jump])
    expect(codes("ok", pain_score: 5, previous_pain_score: 3)).to be_empty
  end

  it "keeps self-harm words even inside a negative sentence about life" do
    expect(codes("Ich will manchmal nicht mehr leben")).to eq(%w[self_harm])
  end
end
