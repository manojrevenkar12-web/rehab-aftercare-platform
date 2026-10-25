# Red-flag hits that context set aside ("mein Mann ist gestürzt") are kept with the check-in so
# the therapist sees what the rules decided not to escalate, and why.
class AddSetAsideToCheckIns < ActiveRecord::Migration[8.1]
  def change
    add_column :check_ins, :set_aside, :jsonb, null: false, default: []
  end
end
