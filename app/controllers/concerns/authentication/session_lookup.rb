module Authentication::SessionLookup
  def find_session
    request.format.json? ? find_session_by_bearer_token : find_session_by_cookie
  end

  private
    def find_session_by_cookie
      if token = cookies.signed[:session_token]
        find_session_by_token(token)
      end
    end

    def find_session_by_bearer_token
      if token = parse_bearer_token
        find_session_by_token(token)
      end
    end

    def find_session_by_token(token)
      Session.find_by(token: token)
    end

    def parse_bearer_token
      pattern = /^Bearer (.+)$/
      request.headers["Authorization"]&.match(pattern)&.captures&.first
    end
end
