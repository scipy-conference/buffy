require_relative '../lib/responder'

class BuildPaperResponder < Responder

  keyname :build_paper

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name}\s*build\s*paper\s*\z/i
    @procbuild_url = @env[:procbuild_url]
  end

  def process_message(message)
    respond("building paper...")
    # first we need the user and branch info
    # puts "locals are #{locals}"
    # TODO how do we get the whole payload here?
    # puts "context is #{context}"
    url = context.payload.dig("issue", "pull_request", "url")
    # url = context.payload[:issue][:pull_request][:url]
    # puts "url is #{url}"
    response = Faraday.get(url)
    data = JSON.parse response.body
    # puts "response json is #{data}"
    user = context.payload.dig("issue", "user", "login")
    # puts "user is #{user}"
    branch = data["head"]["ref"].gsub("/", "-")
    owner = data["head"]["repo"]["owner"]["login"]
    # puts "branch is #{branch}"
    # then we can construct the build url
    url = "#{@procbuild_url}/build/#{owner}-#{branch}"
    puts "url is #{url}"
    # and call the service
    response = Faraday.get(url)
    data = JSON.parse response.body
    puts "procbuild response is #{data}"
    # ExternalServiceWorker.perform_async(params, locals)
    # TODO make this look nicer
    respond("#{data}")
  end

  def description
    params[:description] || "Builds paper"
  end

  def example_invocation
    "@#{bot_name} build paper"
  end
end
