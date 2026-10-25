require "rails_helper"

RSpec.describe "Sessions", type: :request do
  let!(:user) { create(:user, :therapist, email: "theo@clinic.example") }

  it "issues a token for the right password, and the token works until revoked" do
    api :post, "/api/v1/session", params: { email: " Theo@Clinic.example ", password: "correct horse battery" }
    expect(response).to have_http_status(:created)
    token = json["token"]
    headers = { "Authorization" => "Bearer #{token}" }
    get "/api/v1/session", headers: headers
    expect(json.dig("user", "role")).to eq("therapist")
    delete "/api/v1/session", headers: headers
    get "/api/v1/session", headers: headers
    expect(response).to have_http_status(:unauthorized)
  end

  it "refuses a wrong password without saying which part was wrong" do
    api :post, "/api/v1/session", params: { email: "theo@clinic.example", password: "nope" }
    expect(response).to have_http_status(:unauthorized)
    expect(json["error"]).to eq("Wrong e-mail or password.")
  end

  it "refuses an expired token" do
    _t, raw = ApiToken.issue(user, ttl: 1.minute)
    travel 2.minutes
    get "/api/v1/caseload", headers: { "Authorization" => "Bearer #{raw}" }
    expect(response).to have_http_status(:unauthorized)
  end

  it "stores only a digest of the token" do
    _t, raw = ApiToken.issue(user)
    expect(ApiToken.pluck(:token_digest)).not_to include(raw)
  end
end
