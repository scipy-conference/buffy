require_relative '../lib/responder'

class BuildStatusResponder < Responder

  keyname :build_status

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name}\s*build\s*status\s*\z/i
    @procbuild_url = @env[:procbuild_url]
  end

  def process_message(message)
    # first we need the user and branch info
    url = context.raw_payload.dig("issue", "pull_request", "url")
    response = Faraday.get(url)
    data = JSON.parse response.body
    user = context.raw_payload.dig("issue", "user", "login")
    branch = data["head"]["ref"].gsub("/", "-")
    owner = data["head"]["repo"]["owner"]["login"]
    # then we can construct the paper status url
    url = "#{@procbuild_url}/status/#{owner}-#{branch}"
    # and ping procbuild
    response = Faraday.get(url)
    data = JSON.parse response.body
    respond("#{data}")
  end

  def description
    params[:description] || "Checks build status"
  end

  def example_invocation
    "@#{bot_name} build status"
  end
end
