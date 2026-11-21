namespace :ai do
  desc "Compare a workflow's newest prompt/model release with the one before, on reviewers' decisions: " \
       "bin/rails ai:release_gate[kind] or ai:release_gate[kind,baseline_version@model,candidate_version@model]. " \
       "Exits 1 when the candidate is worse (block), 2 when it cannot decide yet (wait), 0 on pass."
  task :release_gate, %i[kind baseline candidate] => :environment do |_, args|
    gate = Ops::ReleaseGate.new
    kinds = args[:kind].present? ? [ args[:kind] ] : AiDraft::KINDS
    abort("unknown kind #{args[:kind]}; one of #{AiDraft::KINDS.join(', ')}") if (kinds - AiDraft::KINDS).any?

    verdicts =
      if args[:baseline].present?
        [ gate.compare(kinds.first, baseline: Ops::ReleaseGate::Release.parse(args[:baseline]),
                                    candidate: Ops::ReleaseGate::Release.parse(args[:candidate])) ]
      else
        gate.all(kinds)
      end
    verdicts.each do |v|
      puts "#{v.kind}: #{v.decision.upcase} #{v.baseline&.release&.label || '–'} → #{v.candidate&.release&.label || '–'}"
      v.reasons.each { |r| puts "  #{r}" }
    end
    exit 1 if verdicts.any?(&:blocked?)
    exit 2 if args[:baseline].present? && verdicts.first.decision == "wait"
  end
end
