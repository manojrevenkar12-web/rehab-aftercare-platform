# What the operations view and the release gate read.
#
# ai_calls: one row per request to a model — which workflow, prompt version and model, how long it
# took, how many tokens, what it cost, and whether it worked. No messages and no output: the
# ledger holds numbers only, so it can be kept and aggregated without holding health data.
#
# check_ins.answered_at: when the approved reply went out, so "answered within 24 hours" is
# measured, not inferred from updated_at.
#
# ai_drafts.edited: whether the reviewer changed the draft before approving it. With rejections,
# this is the signal the release gate compares between prompt versions and models.
class AddOperationsLedger < ActiveRecord::Migration[8.1]
  def change
    create_table :ai_calls do |t|
      t.references :clinic, foreign_key: true, index: false
      t.string :task, null: false
      t.string :prompt_version
      t.string :model, null: false
      t.string :provider, null: false
      t.string :outcome, null: false
      t.integer :latency_ms, null: false
      t.integer :input_tokens, null: false, default: 0
      t.integer :output_tokens, null: false, default: 0
      t.boolean :tokens_estimated, null: false, default: false
      t.bigint :cost_microeuros, null: false, default: 0
      t.datetime :created_at, null: false
      t.check_constraint "outcome IN ('ok','error','refused')", name: "ai_calls_outcome_known"
      t.check_constraint "latency_ms >= 0 AND input_tokens >= 0 AND output_tokens >= 0 AND cost_microeuros >= 0", name: "ai_calls_not_negative"
    end
    add_index :ai_calls, %i[clinic_id created_at]
    add_index :ai_calls, %i[task created_at]

    add_column :check_ins, :answered_at, :datetime
    add_index :check_ins, :submitted_at

    add_column :ai_drafts, :edited, :boolean
    add_index :ai_drafts, %i[kind prompt_version model]
  end
end
