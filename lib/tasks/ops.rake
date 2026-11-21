namespace :ops do
  desc "Print the operations snapshot of a clinic as Markdown (default: the demo clinic): bin/rails ops:report[ik_number]"
  task :report, [ :ik ] => :environment do |_, args|
    clinic = Clinic.find_by!(ik_number: args[:ik].presence || "260999001")
    puts Ops::Report.markdown(Ops::Snapshot.new(clinic).to_h)
  end
end
