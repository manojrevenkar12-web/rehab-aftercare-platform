# Who may do what. Every rule reads from three facts about the user and the record: the user's
# role, whether the record belongs to the user's clinic, and whether a therapist is assigned to
# the patient. Clinical free text (check-ins, notes, drafts) is for the people treating the
# patient; billing and administration see administrative fields only.
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "not signed in" unless user

    @user = user
    @record = record
  end

  def index? = false
  def show? = false
  def create? = false
  def update? = false
  def destroy? = false

  private

  def patient_of(record)
    case record
    when Patient then record
    when Enrolment then record.patient
    when TrainingUnit, CheckIn, AiDraft, ClosingReport, Claim, PlanItem then record.enrolment.patient
    end
  end

  def same_clinic?(rec = record)
    patient_of(rec)&.clinic_id == user.clinic_id
  end

  def assigned?(rec = record)
    p = patient_of(rec)
    user.therapist? && p && CareAssignment.exists?(patient_id: p.id, therapist_id: user.id, active: true)
  end

  def own?(rec = record)
    user.patient? && patient_of(rec)&.user_id == user.id
  end

  # Treating the patient: the assigned therapist or any physician of the clinic.
  def treating?(rec = record)
    assigned?(rec) || (user.physician? && same_clinic?(rec))
  end

  def administrative?(rec = record)
    (user.clinic_admin? || user.billing?) && same_clinic?(rec)
  end

  class Scope
    def initialize(user, scope)
      raise Pundit::NotAuthorizedError, "not signed in" unless user

      @user = user
      @scope = scope
    end

    private

    attr_reader :user, :scope
  end
end
