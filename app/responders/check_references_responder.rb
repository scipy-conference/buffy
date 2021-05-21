require_relative '../lib/responder'

class CheckReferencesResponder < Responder

  keyname :check_references

  def define_listening
    @event_action = "issue_comment.created"
    @event_regex = /\A@#{bot_name} check references(?: from branch ([\w-]+))?\s*\z/i
  end

  def process_message(message)
    url = context.payload.dig("issue", "pull_request", "url")
    response = Faraday.get(url)
    data = JSON.parse response.body
    branch_name_value = data["head"]["ref"]
    puts "found branch name #{branch_name}"
    target_repo_value = data["head"]["repo"]["html_url"]
    puts "found repo #{repo}"
    DOIWorker.perform_async(locals, target_repo_value, branch_name_value)
  end

  def description
    "Check the references of the paper for missing DOIs" + "\n" +
    "# Optionally, it can be run on a non-default branch "
  end

  def example_invocation
    "@#{bot_name} check references" + "\n" +
    "@#{bot_name} check references from custom-branch-name"
  end
end
