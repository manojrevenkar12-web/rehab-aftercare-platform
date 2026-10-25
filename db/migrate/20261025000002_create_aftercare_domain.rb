# The aftercare domain: clinics and their people, patients in DRV digital aftercare programmes,
# the training units they log, check-ins, AI drafts that people review, closing reports, claims,
# and an append-only audit trail.
class CreateAftercareDomain < ActiveRecord::Migration[8.1]
  def change
    create_table :clinics do |t|
      t.string :name, null: false
      t.string :ik_number, null: false # Institutionskennzeichen, the clinic's billing identity
      t.timestamps
      t.index :ik_number, unique: true
    end

    create_table :users do |t|
      t.references :clinic, null: false, foreign_key: true
      t.string :email, null: false
      t.string :name, null: false
      t.string :role, null: false
      t.string :password_digest, null: false
      t.timestamps
      t.index :email, unique: true
      t.check_constraint "role IN ('clinic_admin','physician','therapist','billing','patient')", name: "users_role_known"
    end

    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_used_at
      t.timestamps
      t.index :token_digest, unique: true
    end

    create_table :patients do |t|
      t.references :clinic, null: false, foreign_key: true
      t.references :user, foreign_key: true # the patient's own login, if any
      t.string :pseudonym, null: false # what logs, jobs and models see
      t.string :full_name, null: false
      t.date :birth_date, null: false
      t.string :insurance_number, null: false # Rentenversicherungsnummer
      t.string :phone
      t.string :email
      t.date :rehab_ended_on, null: false
      t.string :indication, null: false # orthopaedics, neurology, cardiology, obesity, psychosomatics
      t.timestamps
      t.index :pseudonym, unique: true
      t.index [ :clinic_id, :insurance_number ], unique: true
    end

    create_table :care_assignments do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :therapist, null: false, foreign_key: { to_table: :users }
      t.boolean :active, null: false, default: true
      t.timestamps
      t.index [ :patient_id, :therapist_id ], unique: true
    end

    create_table :enrolments do |t|
      t.references :patient, null: false, foreign_key: true
      t.string :programme, null: false
      t.integer :units_required, null: false
      t.string :cost_approval_ref # the DRV's cost approval (form G4802)
      t.date :approved_on
      t.string :status, null: false, default: "referred"
      t.date :started_on
      t.date :completed_on
      t.date :ended_on
      t.string :end_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.check_constraint "status IN ('referred','approved','active','completed','ended_early','expired')", name: "enrolments_status_known"
      t.check_constraint "units_required > 0", name: "enrolments_units_positive"
    end

    create_table :training_units do |t|
      t.references :enrolment, null: false, foreign_key: true
      t.references :therapist, foreign_key: { to_table: :users }
      t.date :performed_on, null: false
      t.integer :duration_minutes, null: false
      t.string :source, null: false
      t.integer :pain_before
      t.integer :pain_after
      t.integer :effort
      t.text :note
      t.string :idempotency_key, null: false
      t.timestamps
      t.index [ :enrolment_id, :idempotency_key ], unique: true
      t.index [ :enrolment_id, :performed_on ]
      t.check_constraint "source IN ('patient_app','therapist')", name: "training_units_source_known"
      t.check_constraint "pain_before BETWEEN 0 AND 10 AND pain_after BETWEEN 0 AND 10", name: "training_units_pain_scale"
      t.check_constraint "effort IS NULL OR effort BETWEEN 0 AND 10", name: "training_units_effort_scale"
      t.check_constraint "duration_minutes > 0", name: "training_units_duration_positive"
    end

    create_table :check_ins do |t|
      t.references :enrolment, null: false, foreign_key: true
      t.datetime :submitted_at, null: false
      t.integer :pain_score, null: false
      t.text :message, null: false
      t.jsonb :red_flags, null: false, default: []
      t.string :status, null: false, default: "new"
      t.timestamps
      t.check_constraint "status IN ('new','escalated','answered')", name: "check_ins_status_known"
    end

    create_table :ai_drafts do |t|
      t.references :enrolment, null: false, foreign_key: true
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.string :kind, null: false
      t.string :status, null: false, default: "queued"
      t.string :input_digest, null: false
      t.string :model
      t.string :prompt_version, null: false
      t.jsonb :output, null: false, default: {}
      t.jsonb :findings, null: false, default: []
      t.text :error
      t.datetime :reviewed_at
      t.timestamps
      t.index [ :enrolment_id, :kind, :input_digest ], unique: true, name: "ai_drafts_one_per_input"
      t.check_constraint "kind IN ('check_in_reply','closing_report','plan_change')", name: "ai_drafts_kind_known"
      t.check_constraint "status IN ('queued','ready','held','failed','approved','rejected')", name: "ai_drafts_status_known"
    end

    create_table :exercises do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :body_region, null: false
      t.integer :level, null: false
      t.jsonb :contraindications, null: false, default: []
      t.index :key, unique: true
    end

    create_table :plan_items do |t|
      t.references :enrolment, null: false, foreign_key: true
      t.references :exercise, null: false, foreign_key: true
      t.integer :sets, null: false
      t.integer :reps, null: false
      t.integer :per_week, null: false
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :closing_reports do |t|
      t.references :enrolment, null: false, foreign_key: true, index: { unique: true }
      t.references :ai_draft, foreign_key: true
      t.jsonb :sections, null: false, default: {}
      t.references :signed_by, foreign_key: { to_table: :users }
      t.datetime :signed_at
      t.timestamps
    end

    create_table :claims do |t|
      t.references :enrolment, null: false, foreign_key: true, index: { unique: true }
      t.string :number, null: false
      t.string :status, null: false, default: "draft"
      t.integer :amount_cents, null: false
      t.string :currency, null: false, default: "EUR"
      t.integer :units_billed, null: false
      t.jsonb :documents, null: false, default: {}
      t.jsonb :problems, null: false, default: []
      t.datetime :submitted_at
      t.datetime :settled_at
      t.string :rejection_reason
      t.integer :lock_version, null: false, default: 0
      t.timestamps
      t.index :number, unique: true
      t.check_constraint "status IN ('draft','ready','submitted','paid','rejected','needs_review')", name: "claims_status_known"
      t.check_constraint "amount_cents >= 0", name: "claims_amount_not_negative"
    end

    create_table :audit_events do |t|
      t.references :clinic, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :data, null: false, default: {}
      t.string :prev_digest, null: false
      t.string :digest, null: false
      t.datetime :created_at, null: false
      t.index :digest, unique: true
      t.index [ :subject_type, :subject_id ]
    end

    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE FUNCTION audit_events_append_only() RETURNS trigger AS $$
          BEGIN
            RAISE EXCEPTION 'audit_events is append-only';
          END;
          $$ LANGUAGE plpgsql;
          CREATE TRIGGER audit_events_no_update BEFORE UPDATE OR DELETE ON audit_events
            FOR EACH ROW EXECUTE FUNCTION audit_events_append_only();
        SQL
      end
      dir.down do
        execute "DROP TRIGGER audit_events_no_update ON audit_events; DROP FUNCTION audit_events_append_only();"
      end
    end
  end
end
