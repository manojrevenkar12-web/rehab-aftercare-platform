FactoryBot.define do
  factory :clinic do
    sequence(:name) { |n| "Reha-Klinik #{n}" }
    sequence(:ik_number) { |n| (260_000_000 + n).to_s }
  end

  factory :user do
    clinic
    sequence(:email) { |n| "user#{n}@clinic.example" }
    sequence(:name) { |n| "User #{n}" }
    password { "correct horse battery" }
    role { "therapist" }

    %w[clinic_admin physician therapist billing patient].each do |r|
      trait(r.to_sym) { role { r } }
    end
  end

  factory :patient do
    clinic
    full_name { "Anna Becker" }
    birth_date { Date.new(1968, 3, 14) }
    sequence(:insurance_number) { |n| format("65 140368 B %02d %d", n % 100, n % 10) }
    phone { "+49 30 1234567" }
    email { "anna.becker@mail.example" }
    rehab_ended_on { Date.new(2026, 9, 1) }
    indication { "orthopaedics" }
  end

  factory :enrolment do
    patient
    programme { "t_rena_digital" }

    trait :approved do
      status { "approved" }
      cost_approval_ref { "G4802-2026-0042" }
      approved_on { patient.rehab_ended_on + 3.days }
    end
  end

  factory :exercise do
    sequence(:key) { |n| "ex_#{n}" }
    name { "Bridging" }
    body_region { "lumbar" }
    level { 1 }
    contraindications { [] }
  end
end
