require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  ALLOWED_BROWSER    = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15"
  DISALLOWED_BROWSER = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/114.0"

  test "new" do
    get new_session_url
    assert_response :success
  end

  test "new redirects to first run when no users exist" do
    User.destroy_all

    get new_session_url

    assert_redirected_to first_run_url
  end

  test "new denied with incompatible browser" do
    get new_session_url, env: { "HTTP_USER_AGENT" => DISALLOWED_BROWSER }
    assert_select "svg", message: /Your browser is not supported/
  end

  test "new allowed with compatible browser" do
    get new_session_url, env: { "HTTP_USER_AGENT" => ALLOWED_BROWSER }
    assert_select "svg", message: /Your browser is not supported/, count: 0
  end

  test "create with valid credentials" do
    assert_difference -> { Session.count }, +1 do
      post session_url, params: { email_address: "david@example.com", password: "secret123456" }
    end

    assert_redirected_to root_url
    assert parsed_cookies.signed[:session_token]
  end

  test "create with invalid credentials" do
    post session_url, params: { email_address: "david@example.com", password: "wrong" }

    assert_response :unauthorized
    assert_nil parsed_cookies.signed[:session_token]
  end

  test "destroy" do
    sign_in :david
    session = users(:david).sessions.last

    assert_difference -> { Session.count }, -1 do
      delete session_url
    end

    assert_redirected_to root_url
    assert_not cookies[:session_token].present?
    assert_nil Session.find_by(id: session.id)
  end

  test "valid bearer token authenticates protected JSON endpoint" do
    sign_in :david
    session = users(:david).sessions.last
    session.update!(last_active_at: 2.hours.ago)
    original_last_active_at = session.last_active_at

    post books_url(format: :json), headers: { "Authorization" => "Bearer #{session.token}" },
      params: { book: { title: "Test Book" } }

    assert_not_equal 401, response.status
    session.reload
    assert session.last_active_at > original_last_active_at
  end

  test "missing bearer token on protected JSON endpoint returns 401" do
    delete session_url(format: :json)

    assert_response :unauthorized
    assert_equal "unauthenticated", JSON.parse(response.body).dig("error", "code")
  end

  test "invalid bearer token returns 401" do
    delete session_url(format: :json), headers: { "Authorization" => "Bearer invalid_token" }

    assert_response :unauthorized
    assert_equal "unauthenticated", JSON.parse(response.body).dig("error", "code")
  end

  test "malformed Authorization header returns 401" do
    delete session_url(format: :json), headers: { "Authorization" => "NotBearer token" }

    assert_response :unauthorized
    assert_equal "unauthenticated", JSON.parse(response.body).dig("error", "code")
  end

  test "create JSON with valid credentials returns token payload" do
    post session_url(format: :json), params: { email_address: "david@example.com", password: "secret123456" }

    assert_response :ok

    json = JSON.parse(response.body)

    assert json["token"].present?
    assert_equal "David", json["name"]
    assert_equal "david@example.com", json["email_address"]
    assert_equal users(:david).id, json["user_id"]
    assert Session.find_by(token: json["token"])
  end

  test "create JSON with bad credentials returns unauthenticated" do
    post session_url(format: :json), params: { email_address: "david@example.com", password: "wrong" }

    assert_response :unauthorized
    assert_equal "unauthenticated", JSON.parse(response.body).dig("error", "code")
  end

  test "create JSON with missing credentials returns unauthenticated" do
    post session_url(format: :json), params: { email_address: "david@example.com" }

    assert_response :unauthorized
    assert_equal "unauthenticated", JSON.parse(response.body).dig("error", "code")
  end

  test "destroy JSON with valid bearer token returns no content and invalidates session" do
    sign_in :david
    session = users(:david).sessions.last

    delete session_url(format: :json), headers: { "Authorization" => "Bearer #{session.token}" }

    assert_response :no_content
    assert_nil Session.find_by(id: session.id)

    delete session_url(format: :json), headers: { "Authorization" => "Bearer #{session.token}" }
    assert_response :unauthorized
  end
end
