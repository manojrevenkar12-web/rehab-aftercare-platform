namespace :evals do
  desc "Run the evaluation on the dev set: bin/rails evals:run[label]"
  task :run, [ :label ] => :environment do |_, args|
    label = args[:label] || "dev"
    doc = Evals::Report.write(label, Evals::Runner.new(Rails.root.join("evals/dev")).run, set: "dev")
    puts Evals::Report.markdown(doc)
  end

  desc "Fail when the dev-set report misses a threshold in config/evals.yml"
  task :gate, [ :label ] => :environment do |_, args|
    doc = JSON.parse(File.read(Rails.root.join("reports/evals/#{args[:label] || 'dev'}.json")))
    failures = Evals::Gate.check(doc)
    if failures.any?
      warn failures.map { |f| "GATE FAILED: #{f}" }.join("\n")
      exit 1
    end
    puts "evaluation gate passed"
  end

  desc "Record the first run of a held-out set (once): bin/rails evals:heldout[set]"
  task :heldout, [ :set ] => :environment do |_, args|
    set = args[:set] || abort("name the held-out set")
    dir = Rails.root.join("evals/heldout/#{set}")
    abort("#{dir} is marked #{dir.join('STATUS').read.strip}; it is no longer held out") if dir.join("STATUS").exist?
    doc = Evals::Report.write("heldout-#{set}", Evals::Runner.new(dir).run, set: "heldout/#{set}", first_run_only: true)
    puts Evals::Report.markdown(doc)
  end
end

namespace :evals do
  desc "Run a studied held-out set as a regression set: bin/rails evals:regression[set1]"
  task :regression, [ :set ] => :environment do |_, args|
    set = args[:set] || abort("name the set")
    dir = Rails.root.join("evals/heldout/#{set}")
    abort("#{set} is still held out; record its first run with evals:heldout") unless dir.join("STATUS").exist? && dir.join("STATUS").read.strip == "regression"
    doc = Evals::Report.write("regression-#{set}", Evals::Runner.new(dir).run, set: "heldout/#{set} (regression)")
    puts Evals::Report.markdown(doc)
  end
end

namespace :evals do
  desc "Run the red-flag suite with a real model screen (AI_PROVIDER, AI_MODEL...): bin/rails evals:screen[set2]"
  task :screen, [ :set ] => :environment do |_, args|
    set = args[:set] || abort("name the set: dev, set1 or set2")
    client = Ai::Client.default
    abort("evals:screen needs a real model (AI_PROVIDER=openai_compatible); the simulated one cannot read") if client.provider.is_a?(Ai::Providers::Simulated)
    dir = set == "dev" ? Rails.root.join("evals/dev") : Rails.root.join("evals/heldout/#{set}")
    held_out = set != "dev" && !dir.join("STATUS").exist?
    label = "screen-#{set}-#{client.model.to_s.parameterize}"
    doc = Evals::Report.write(label, Evals::Runner.new(dir, screen_client: client).run(suites: %w[red_flags]),
                              set: set, first_run_only: held_out)
    puts Evals::Report.markdown(doc)
  end
end
