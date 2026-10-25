source "https://rubygems.org"

ruby "~> 3.3"

gem "rails", "~> 8.1.0"
gem "pg", "~> 1.5"
gem "puma", ">= 6.0"
gem "bcrypt", "~> 3.1"
gem "pundit", "~> 2.4"
gem "rack-cors"
gem "solid_queue"
gem "solid_cache"
gem "bootsnap", require: false
gem "tzinfo-data", platforms: %i[windows jruby]

group :development, :test do
  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
  gem "rspec-rails", "~> 8.0"
  gem "factory_bot_rails"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
end

group :test do
  gem "webmock"
  gem "simplecov", require: false
end
