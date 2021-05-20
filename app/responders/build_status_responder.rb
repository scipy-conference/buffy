require_relative '../lib/responder'

class BuildPaperResponder < Responder

  keyname :build_paper

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name}\s*build\s*status\s*\z/i
    @procbuild_url = @env[:procbuild_url]
  end

  def process_message(message)
    respond("building paper...")
    # first we need the user and branch info
    url = context.payload.dig("issue", "pull_request", "url")
    response = Faraday.get(url)
    data = JSON.parse response.body
    user = context.payload.dig("issue", "user", "login")
    branch = data["head"]["ref"].gsub("/", "-")
    # then we can construct the paper status url
    url = "#{@procbuild_url}/status/#{user}-#{branch}"
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
