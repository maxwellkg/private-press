module JSONErrors
  extend ActiveSupport::Concern

  def render_json_error(code, message = nil)
    render json: { error: { code:, message: } }, status: status_for_code(code)
  end

  private
    STATUS_MAPPINGS = {
      unauthenticated: 401,
      forbidden: 403,
      not_found: 404,
      validation_failed: 422,
      rate_limited: 429
    }.freeze

    def status_for_code(code)
      STATUS_MAPPINGS.fetch(code)
    end
end
