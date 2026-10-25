module TestDatabase
  # Empties the application's tables (TRUNCATE is not blocked by the audit trail's row trigger).
  def self.truncate!
    tables = ActiveRecord::Base.connection.tables - %w[schema_migrations ar_internal_metadata]
    ActiveRecord::Base.connection.execute("TRUNCATE #{tables.map { |t| %("#{t}") }.join(', ')} RESTART IDENTITY CASCADE")
  end
end
