# The console is served from the same origin as the API, so no cross-origin access is needed.
# A separate front end (a patient app, say) is allowed only from the origins listed in
# CORS_ORIGINS (comma-separated); nothing is allowed by default.
origins = ENV.fetch("CORS_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)
if origins.any?
  Rails.application.config.middleware.insert_before 0, Rack::Cors do
    allow do
      origins(*origins)
      resource "/api/*", headers: %w[Authorization Content-Type Accept], methods: %i[get post delete options], max_age: 600
    end
  end
end
