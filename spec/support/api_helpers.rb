module ApiHelpers
  def auth_for(user)
    _token, raw = ApiToken.issue(user)
    { "Authorization" => "Bearer #{raw}", "Content-Type" => "application/json", "Accept" => "application/json" }
  end

  def api(method, path, user: nil, params: nil, headers: {})
    h = (user ? auth_for(user) : { "Content-Type" => "application/json" }).merge(headers)
    send(method, path, params: params && JSON.generate(params), headers: h)
  end

  def json
    JSON.parse(response.body)
  end
end
