# Exercise library (all environments) and a demo clinic with synthetic people: outside production,
# or in a production-mode demo deployment that sets SEED_DEMO=1 (docker compose does).
# Everything here is invented: names, dates, insurance numbers and the clinic.
YAML.safe_load_file(Rails.root.join("config/aftercare/exercises.yml")).fetch("exercises").each do |key, e|
  Exercise.find_or_initialize_by(key: key).update!(name: e["name"], body_region: e["body_region"], level: e["level"], contraindications: e["contraindications"])
end

return if Rails.env.production? && ENV["SEED_DEMO"] != "1"

DemoData.load!
