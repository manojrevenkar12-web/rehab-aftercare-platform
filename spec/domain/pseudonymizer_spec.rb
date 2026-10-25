require "rails_helper"

RSpec.describe Ai::Pseudonymizer do
  let(:identity) do
    { full_name: "Anna-Lena Becker", birth_date: Date.new(1968, 3, 14), insurance_number: "65 140368 B 01 2",
      phone: "+49 30 1234567", email: "anna.becker@mail.example" }
  end
  let(:p) { described_class.new(identity) }

  it "replaces the patient's identity in its usual written forms" do
    text = "Hallo, hier ist Anna-Lena Becker (geb. 14.03.1968, RV-Nr. 65140368B012). Beckers Knie tut weh. " \
           "Erreichbar unter 030 / 123 45 67 oder anna.becker@mail.example. Born 14 March 1968."
    out = p.call(text).text
    expect(out).not_to include("Becker", "Anna", "1968", "140368", "1234567", "45 67", "mail.example")
    expect(out).to include("[NAME]", "[BIRTH-DATE]", "[INSURANCE-NO]", "[PHONE]", "[E-MAIL]")
    expect(out).to include("Knie tut weh")
  end

  it "also removes identifiers it was not told about" do
    out = p.call("Meine Tochter: tochter@example.org, 0171 9876543, ihre RV-Nr. 12 010190 M 03 5").text
    expect(out).not_to include("tochter@", "9876543", "010190")
  end

  it "finds identity in a serialised request, and restores placeholders for people allowed to read them" do
    expect(p.leaks('{"message":"Gruss, A. BECKER"}')).to eq([ "name_part_2" ])
    expect(p.leaks('{"message":"[NAME-2] meldet Schmerzen"}')).to be_empty
    expect(p.restore("Liebe [NAME-1] [NAME-2]")).to eq("Liebe Anna Lena") # parts split on hyphen
  end

  it "does not mistake ordinary words for short name parts" do
    q = described_class.new(full_name: "Li Wu", birth_date: Date.new(1990, 1, 2))
    expect(q.call("Links tut es weh, wurde besser").text).to eq("Links tut es weh, wurde besser")
  end

  it "matches a name however its umlauts are written, and dates and phones with any separator" do
    q = described_class.new(full_name: "Jürgen Strauß", birth_date: Date.new(1957, 9, 3), phone: "0221 4455667")
    out = q.call("Gruß von Juergen Strauss, geb. 3-9-57 bzw. 3. Sept. '57, Tel. 0221.445.56.67").text
    expect(out).not_to include("Juergen", "Strauss", "3-9-57", "57", "445")
    expect(q.leaks('{"m":"juergen"}')).to eq([ "name_part_0" ])
  end
end
