class Twitter::SendReplyService
  pattr_initialize [:message!]

  def perform
    return if message.private
    return if message.source_id
    return if inbox.channel.class.to_s != 'Channel::TwitterProfile'
    return unless outgoing_message_from_chatwoot?

    send_reply
  end

  private

  def twitter_client
    Twitty::Facade.new do |config|
      config.consumer_key = ENV.fetch('TWITTER_CONSUMER_KEY', nil)
      config.consumer_secret = ENV.fetch('TWITTER_CONSUMER_SECRET', nil)
      config.access_token = channel.twitter_access_token
      config.access_token_secret = channel.twitter_access_token_secret
      config.base_url = 'https://api.twitter.com'
      config.environment = ENV.fetch('TWITTER_ENVIRONMENT', '')
    end
  end

  def conversation_type
    conversation.additional_attributes['type']
  end

  def screen_name
    "@#{additional_attributes ? additional_attributes['screen_name'] : ''} "
  end

  def send_direct_message
    twitter_client.send_direct_message(
      recipient_id: contact_inbox.source_id,
      message: message.content
    )
  end

  def send_tweet_reply
    response = twitter_client.send_tweet_reply(
      reply_to_tweet_id: conversation.additional_attributes['tweet_id'],
      tweet: screen_name + message.content
    )
    if response.status == '200'
      tweet_data = response.body
      message.update!(source_id: tweet_data['id_str'])
    else
      Rails.logger.info 'TWITTER_TWEET_REPLY_ERROR' + response.body
    end
  end

  def send_reply
    conversation_type == 'tweet' ? send_tweet_reply : send_direct_message
  end

  def outgoing_message_from_chatwoot?
    message.outgoing?
  end

  delegate :additional_attributes, to: :contact
  delegate :contact, to: :conversation
  delegate :contact_inbox, to: :conversation
  delegate :conversation, to: :message
  delegate :inbox, to: :conversation
  delegate :channel, to: :inbox
end
