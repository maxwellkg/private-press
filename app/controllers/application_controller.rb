class ApplicationController < ActionController::Base
  include Authentication, Authorization, JSONErrors, VersionHeaders

  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern, unless: -> { request.format.json? }

  private
    def handle_record_not_found(error)
      if request.format.json?
        render_json_error(:not_found, "Not found.")
      else
        raise error
      end
    end
end
