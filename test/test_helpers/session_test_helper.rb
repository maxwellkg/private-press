module SessionTestHelper
  def parsed_cookies
    ActionDispatch::Cookies::CookieJar.build(request, cookies.to_hash)
  end

  def sign_in(user)
    sign_in_user(user)
    assert cookies[:session_token].present?
  end

  def sign_out
    delete session_url
    assert_not cookies[:session_token].present?
  end

  def authorization_headers_for_user(user)
    authorization_headers_for_token(bearer_token_for(user))
  end

  private
    def authorization_headers_for_token(token)
      { "Authorization" => "Bearer #{token}" }
    end

    def bearer_token_for(user)
      sign_in_json(user)
      JSON.parse(response.body).fetch("token")
    end

    def sign_in_json(user)
      sign_in_user(user, format: :json)
    end

    def sign_in_user(user, format: nil)
      user = users(user) unless user.is_a? User
      create_user_session(user, format:)
    end

    def create_user_session(user, format: nil)
      post session_url, **{
        params: { email_address: user.email_address, password: "secret123456" },
        as: format
      }.compact_blank
    end
end
