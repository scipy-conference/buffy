require_relative '../lib/responder'

class HelpResponder < Responder

  keyname :help

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} #{help_command}[\.!]?\s*$/i
  end

  def process_message(message)
    descriptions_and_examples = []
    visible_responders = ResponderRegistry.new(@settings).responders.select {|r| !r.hidden? }
    puts "visible responders: #{visible_responders}"
    comment_responders = visible_responders.select{|r| r.responds_on?(context)}
    # TODO is this broken?
    # active_responders = comment_responders.select {|r| r.authorized?(context)}
    active_responders = comment_responders.select {|r| r.context = context; r.authorized?(context) }

    active_responders.each do |r|
      puts "responder: #{r}"
      if r.description.is_a? Array
        r.description.zip(r.example_invocation).each do |d_and_ex|
          puts "details: #{d_and_ex}"
          descriptions_and_examples << [d_and_ex[0], d_and_ex[1]]
        end
      else
        descriptions_and_examples << [r.description, r.example_invocation]
      end
    end
    respond_template :help, { sender: context.sender, descriptions_and_examples: descriptions_and_examples }
  end

  def help_command
    params[:help_command] || "help"
  end

  def default_description
    "List all available commands"
  end

  def default_example_invocation
    "@#{bot_name} #{help_command}"
  end
end
