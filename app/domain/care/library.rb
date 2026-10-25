module Care
  # The exercise library as the plan rules and the agent's tools read it.
  module Library
    module_function

    def to_h
      Exercise.all.to_h do |e|
        [ e.key, { "name" => e.name, "body_region" => e.body_region, "level" => e.level, "contraindications" => e.contraindications } ]
      end
    end
  end
end
