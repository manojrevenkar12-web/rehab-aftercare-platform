module Aftercare
  # The DRV programme rules, from config/aftercare/programmes.yml. Code never hard-codes a unit
  # count, a deadline or a rate.
  module Programmes
    Rules = Data.define(:key, :name, :units, :unit_minutes, :min_unit_minutes, :rate_cents_per_unit, :rate_source) do
      def units_for(indication)
        units.fetch(indication.to_s, units.fetch("default"))
      end
    end

    Deadlines = Data.define(:ideal_start_weeks, :latest_start_months, :latest_finish_months, :max_break_weeks, :warn_days_before)

    module_function

    def config
      @config ||= YAML.safe_load_file(Rails.root.join("config/aftercare/programmes.yml")).deep_symbolize_keys
    end

    def reload!
      @config = nil
    end

    def keys
      config.fetch(:programmes).keys.map(&:to_s)
    end

    def fetch(key)
      raw = config.fetch(:programmes).fetch(key.to_sym) { raise KeyError, "unknown programme #{key}" }
      Rules.new(
        key: key.to_s,
        name: raw.fetch(:name),
        units: raw.fetch(:units).transform_keys(&:to_s),
        unit_minutes: raw.fetch(:unit_minutes),
        min_unit_minutes: raw.fetch(:min_unit_minutes),
        rate_cents_per_unit: raw.fetch(:rate_cents_per_unit),
        rate_source: raw.fetch(:rate_source)
      )
    end

    def deadlines
      Deadlines.new(**config.fetch(:deadlines).slice(*Deadlines.members))
    end

    def billing
      config.fetch(:billing)
    end
  end
end
