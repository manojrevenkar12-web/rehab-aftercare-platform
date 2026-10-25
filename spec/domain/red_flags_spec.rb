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

  it "takes a denial after the symptom, but not a symptom that will not go away" do
    expect(codes("Atemnot? Nein, alles gut")).to be_empty
    expect(codes("Fieber hatte ich keins")).to be_empty
    expect(codes("Brustschmerzen, die nicht weggehen")).to eq(%w[chest_pain])
  end

  it "reads umlauts, dialect and word order patients actually use" do
    expect(codes("Bin auf die Schulter gefallen")).to eq(%w[fall])
    expect(codes("Es drückt so komisch in der Brust")).to eq(%w[chest_pain])
    expect(codes("Seit heute hängt mein linker Mundwinkel")).to eq(%w[neurological])
    expect(codes("Hat mir gut gefallen, die neue Übung")).to be_empty
    expect(codes("Brustwirbelsäule schmerzt nach dem Rudern")).to be_empty
  end

  it "decides fever from the reading" do
    expect(codes("Habe 38,4 gemessen")).to eq(%w[wound_or_fever])
    expect(codes("Fieber gemessen, 37,2, also alles normal")).to be_empty
  end

  describe "context" do
    def screen(msg) = described_class.screen(message: msg)

    it "sets aside someone else's event, and keeps the patient's own" do
      s = screen("Meine Frau ist gestern im Garten gestürzt")
      expect(s.flags).to be_empty
      expect(s.set_aside.map { |a| [ a.code, a.reason ] }).to eq([ %w[fall someone_else] ])
      expect(codes("Meine Frau sagt, ich rede seit dem Mittag verwaschen")).to eq(%w[neurological])
    end

    it "sets aside past events unless they are back" do
      expect(codes("Vor drei Jahren hatte ich einen Infarkt mit Brustschmerzen")).to be_empty
      expect(codes("Wie vor drei Jahren habe ich jetzt wieder Brustschmerzen")).to eq(%w[chest_pain])
    end

    it "sets aside fear of an event and a near miss" do
      expect(codes("Habe Angst, dass ich auf dem Eis stürze und hinfalle")).to be_empty
      expect(codes("Wäre fast hingefallen")).to be_empty
      expect(codes("I'm scared of having chest pain again")).to be_empty
      expect(codes("Habe Angst zu stürzen und habe seit heute Druck auf der Brust")).to eq(%w[chest_pain])
    end

    it "keeps breathlessness unless it is the patient's usual exertion" do
      expect(codes("Kurzatmig auf der Treppe, wie immer")).to be_empty
      expect(codes("Kurzatmig auf der Treppe, schlimmer als sonst")).to eq(%w[breathlessness])
    end
  end
end
