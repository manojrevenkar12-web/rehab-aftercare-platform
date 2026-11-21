module Ops
  # Small, dependency-free statistics for the operations view and the release gate.
  module Stats
    module_function

    # Wilson score interval for k successes in n trials; [nil, nil] with no trials.
    def wilson(k, n, z: 1.96)
      return [ nil, nil ] if n.zero?

      p = k.fdiv(n)
      denom = 1 + (z**2 / n)
      centre = (p + (z**2 / (2 * n))) / denom
      half = (z * Math.sqrt((p * (1 - p) / n) + (z**2 / (4 * n * n)))) / denom
      [ [ centre - half, 0.0 ].max, [ centre + half, 1.0 ].min ]
    end

    # Newcombe's hybrid score interval (method 10) for the difference p_candidate - p_baseline.
    # It behaves at small counts and at rates near 0 or 1, where the plain normal interval does not.
    def difference(k_candidate, n_candidate, k_baseline, n_baseline, z: 1.96)
      return nil if n_candidate.zero? || n_baseline.zero?

      p2 = k_candidate.fdiv(n_candidate)
      p1 = k_baseline.fdiv(n_baseline)
      l2, u2 = wilson(k_candidate, n_candidate, z: z)
      l1, u1 = wilson(k_baseline, n_baseline, z: z)
      d = p2 - p1
      { diff: d, low: d - Math.sqrt(((p2 - l2)**2) + ((u1 - p1)**2)), high: d + Math.sqrt(((u2 - p2)**2) + ((p1 - l1)**2)) }
    end

    # Nearest-rank percentile of a list of numbers; nil for an empty list.
    def percentile(values, pct)
      return nil if values.empty?

      sorted = values.sort
      sorted[[ (pct / 100.0 * sorted.size).ceil - 1, 0 ].max]
    end

    def share(k, n)
      n.zero? ? nil : k.fdiv(n)
    end
  end
end
