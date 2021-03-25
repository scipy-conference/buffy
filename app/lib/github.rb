require 'octokit'

# This module includes all the methods involving calls to the GitHub API
# It reuses a memoized Octokit::Client instance
# Context is an OpenStruct object created in lib/github_webhook_parser or in a BuffyWorker
module GitHub

  # Authenticated Octokit
  def github_client
    @github_client ||= Octokit::Client.new(access_token: @env[:gh_access_token], auto_paginate: true)
  end

  # returns the URL for a given template in the repo
  def template_url(filename)
    github_client.contents(context.repo, path: template_path + filename).download_url
  end

  # Return an Octokit GitHub Issue
  def issue
    @issue ||= github_client.issue(context.repo, context.issue_id)
  end

  # Return the body of issue
  def issue_body
    @issue_body ||= context.issue_body
    @issue_body ||= issue.body
  end

  # Post messages to a GitHub issue.
  def bg_respond(comment)
    github_client.add_comment(context.repo, context.issue_id, comment)
  end

  # Add labels to a GitHub issue
  def label_issue(labels)
    github_client.add_labels_to_an_issue(context.repo, context.issue_id, labels)
  end

  # Remove a label from a GitHub issue
  def unlabel_issue(label)
    github_client.remove_label(context.repo, context.issue_id, label)
  end

  # List labels of a GitHub issue
  def issue_labels
    github_client.labels_for_issue(context.repo, context.issue_id).map { |l| l[:name] }
  end

  # Update a Github issue
  def update_issue(options)
    github_client.update_issue(context.repo, context.issue_id, options)
  end

   # Close a Github issue
  def close_issue(options = {})
    github_client.close_issue(context.repo, context.issue_id, options)
  end

  # Add a user as collaborator to the repo
  def add_collaborator(username)
    username = user_login(username)
    github_client.add_collaborator(context.repo, username)
  end

  # Add a user to the issue's assignees list
  def add_assignee(username)
    username = user_login(username)
    github_client.add_assignees(context.repo, context.issue_id, [username])
  end

  # Remove a user from the issue's assignees list
  def remove_assignee(username)
    username = user_login(username)
    github_client.remove_assignees(context.repo, context.issue_id, [username])
  end

  # Remove a user from repo's collaborators
  def remove_collaborator(username)
    username = user_login(username)
    github_client.remove_collaborator(context.repo, username)
  end

  # Uses the GitHub API to determine if a user is already a collaborator of the repo
  def is_collaborator?(username)
    username = user_login(username)
    github_client.collaborator?(context.repo, username)
  end

  # Uses the GitHub API to determine if a user is already a collaborator of the repo
  def can_be_assignee?(username)
    username = user_login(username)
    github_client.check_assignee(context.repo, username)
  end

  # Uses the GitHub API to determine if a user has a pending invitation
  def is_invited?(username)
    username = user_login(username)
    github_client.repository_invitations(context.repo).any? { |i| i.invitee.login.downcase == username }
  end

  # Uses the GitHub API to obtain the id of an organization's team
  def team_id(org_team_name)
    org_name, team_name = org_team_name.split('/')
    raise "Configuration Error: Invalid team name: #{org_team_name}" if org_name.nil? || team_name.nil?
    begin
      team = github_client.organization_teams(org_name).select { |t| t[:slug] == team_name || t[:name].downcase == team_name.downcase }.first
      team.nil? ? nil : team[:id]
    rescue Octokit::Forbidden
      raise "Configuration Error: No API access to organization: #{org_name}"
    end
  end

  # Returns true if the user in a team member of any of the authorized teams
  # false otherwise
  def user_in_authorized_teams?(user_login)
    @user_authorized ||= begin
      authorized = []
      authorized_team_ids.each do |team_id|
        authorized << github_client.team_member?(team_id, user_login)
        break if authorized.compact.any?
      end
      authorized.compact.any?
    end
  end

  # The url of the invitations page for the current repo
  def invitations_url
    "https://github.com/#{context.repo}/invitations"
  end

  # Returns the user login (removes the @ from the username)
  def user_login(username)
    username.sub(/^@/, "").downcase
  end

  # Returns true if the string is a valid GitHub isername (starts with @)
  def username?(username)
    username.match?(/\A@/)
  end


  module ClassMethods
    # Class method to get team ids for teams configured by name
    def get_team_ids(config)
      teams_hash = config[:teams] || Sinatra::IndifferentHash.new
      gh = nil
      teams_hash.each_pair do |team_name, id_or_slug|
        if id_or_slug.is_a? String
          org_slug, team_slug = id_or_slug.split('/')
          raise "Configuration Error: Invalid team name: #{id_or_slug}" if org_slug.nil? || team_slug.nil?
          gh ||= Octokit::Client.new(access_token: config[:gh_access_token], auto_paginate: true)
          teams_hash[team_name] = begin
            team = gh.organization_teams(org_slug).select { |t| t[:slug] == team_slug || t[:name].downcase == team_slug.downcase }.first
            team.nil? ? nil : team[:id]
          rescue Octokit::Forbidden
            raise "Configuration Error: No API access to organization: #{org_slug}"
          end
        end
      end
      teams_hash
    end
  end

  def self.included base
    base.extend ClassMethods
  end

end