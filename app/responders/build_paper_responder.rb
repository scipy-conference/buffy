require_relative '../lib/responder'

class BuildPaperResponder < Responder

  keyname :build_paper

  def define_listening
    required_params :command

    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name}\s*build\s*paper\s*\z/i
    @procbuild_url = @env[:procbuild_url]
  end

  def process_message(message)
    respond("building paper...")
    # first we need the user and branch info
    url = locals[:issue][:pull_request][:url]
    response = Faraday.get(url)
    user = locals[:issue][:user][:login]
    branch = response[:head][:ref]
    # then we can construct the build url
    params[:url] = "#{procbuild_url}/#{user}-#{branch}"
    # and call the service
    ExternalServiceWorker.perform_async(params, locals)
  end

  def description
    params[:description] || "Builds paper"
  end

  def example_invocation
    "@#{bot_name} build paper"
  end
end
