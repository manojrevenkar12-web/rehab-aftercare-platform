require "rails_helper"

RSpec.describe "The console", type: :request do
  around do |ex|
    index = Rails.public_path.join("index.html")
    existed = index.exist?
    original = index.read if existed
    index.write("<!doctype html><title>Rehab Aftercare</title><div id=root></div>")
    ex.run
  ensure
    existed ? index.write(original) : index.delete
  end

  it "is served for the browser's own routes, but never instead of the API" do
    get "/enrolments/7", headers: { "Accept" => "text/html" }
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Rehab Aftercare")

    get "/api/v1/nothing-here", headers: { "Accept" => "text/html" }
    expect(response).to have_http_status(:not_found)
    expect(response.body).not_to include("Rehab Aftercare")
  end
end
