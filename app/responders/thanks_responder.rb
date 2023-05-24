require_relative '../lib/responder'

class ThanksResponder < Responder

  keyname :thanks

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A(@#{bot_name} thanks|@#{bot_name} thank you|thanks @#{bot_name}|thank you @#{bot_name})/i
  end

  def process_message(message)
    respond(reply)
  end

  def default_description
    "You are welcome"
  end

  def default_example_invocation
    "Thanks @#{bot_name}!"
  end

  def reply
    params[:reply] || "You are welcome"
  end
end
