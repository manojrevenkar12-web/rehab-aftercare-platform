module Ops
  # config/ops.yml, read once.
  module Config
    module_function

    def all
      @all ||= YAML.safe_load_file(Rails.root.join("config/ops.yml")).freeze
    end

    def fetch(*path)
      path.map(&:to_s).reduce(all) { |node, key| node.fetch(key) }
    end
  end
end
