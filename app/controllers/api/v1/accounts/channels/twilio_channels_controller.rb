class Api::V1::Accounts::Channels::TwilioChannelsController < Api::BaseController
  before_action :current_account
  before_action :authorize_request

  def create
    ActiveRecord::Base.transaction do
      authenticate_twilio
      build_inbox
      setup_webhooks if @twilio_channel.sms?
    rescue Twilio::REST::TwilioError => e
      render_could_not_create_error(e.message)
    rescue StandardError => e
      render_could_not_create_error(e.message)
    end
  end

  private

  def authorize_request
    authorize ::Inbox
  end

  def authenticate_twilio
    client = Twilio::REST::Client.new(permitted_params[:account_sid], permitted_params[:auth_token])
    client.messages.list(limit: 1)
  end

  def setup_webhooks
    ::Twilio::WebhookSetupService.new(inbox: @inbox).perform
  end

  def phone_number
    medium == 'sms' ? permitted_params[:phone_number] : "whatsapp:#{permitted_params[:phone_number]}"
  end

  def medium
    permitted_params[:medium]
  end

  def build_inbox
    @twilio_channel = current_account.twilio_sms.create!(
      account_sid: permitted_params[:account_sid],
      auth_token: permitted_params[:auth_token],
      phone_number: phone_number,
      medium: medium
    )
    @inbox = current_account.inboxes.create(
      name: permitted_params[:name],
      channel: @twilio_channel
    )
  end

  def permitted_params
    params.require(:twilio_channel).permit(
      :account_id, :phone_number, :account_sid, :auth_token, :name, :medium
    )
  end
end
