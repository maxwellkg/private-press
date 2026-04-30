class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { render_rate_limit_rejection }

  before_action :ensure_user_exists, only: :new

  def new
  end

  def create
    if user = authenticated_user
      handle_successful_create(user)
    else
      handle_failed_create
    end
  end

  def destroy
    terminate_current_session

    respond_to do |format|
      format.html { redirect_to root_url }
      format.json { head :no_content }
    end
  end

  private
    def ensure_user_exists
      redirect_to first_run_url if User.none?
    end

    def authenticated_user
      User.active.authenticate_by(email_address: params[:email_address], password: params[:password])
    end

    def handle_successful_create(user)
      session = start_new_session_for(user)

      respond_to do |format|
        format.html { redirect_to post_authenticating_url }
        format.json { render json: session_payload(session), status: :ok }
      end
    end

    def handle_failed_create
      respond_to do |format|
        format.html { render_rejection :unauthorized }
        format.json { render_json_error(:unauthenticated) }
      end
    end

    def session_payload(session)
      {
        token: session.token,
        name: session.user.name,
        email_address: session.user.email_address,
        user_id: session.user.id
      }
    end

    def render_rejection(status)
      flash[:alert] = "Too many requests or unauthorized."
      render :new, status: status
    end

    def render_rate_limit_rejection
      respond_to do |format|
        format.html { render_rejection :too_many_requests }
        format.json { render_json_error(:rate_limited) }
      end
    end
end
