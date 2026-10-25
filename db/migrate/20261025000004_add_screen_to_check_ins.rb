# What the model screen did with a check-in: the model and prompt, the flags it added, the ones
# it proposed that were dropped (unknown flag, quote not in the message), or why it did not run.
class AddScreenToCheckIns < ActiveRecord::Migration[8.1]
  def change
    add_column :check_ins, :screen, :jsonb, null: false, default: {}
  end
end
