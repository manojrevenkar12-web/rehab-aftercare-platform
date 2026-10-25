# Exercise library (all environments) and, outside production, a demo clinic with synthetic people.
# Everything here is invented: names, dates, insurance numbers and the clinic.
YAML.safe_load_file(Rails.root.join("config/aftercare/exercises.yml")).fetch("exercises").each do |key, e|
  Exercise.find_or_initialize_by(key: key).update!(name: e["name"], body_region: e["body_region"], level: e["level"], contraindications: e["contraindications"])
end

return if Rails.env.production?

DemoData.load! if defined?(DemoData)
