require_relative "./spec_helper.rb"

describe "Github methods" do

  subject do
    settings = Sinatra::IndifferentHash[env: {}, teams: { editors: 11, reviewers: 22, eics: 33 }]
    params ={ only: ["editors", "eics"] }
    Responder.new(settings, params)
  end

  before do
    subject.context = OpenStruct.new({ repo: "openjournals/buffy", issue_id: 5})
  end

  describe "#github_client" do
    it "should memoize an Octokit Client" do
      expect(Octokit::Client).to receive(:new).once.and_return("whatever")
      subject.github_client
      subject.github_client
    end
  end

  describe "#github_access_token" do
    it "should memoize the access_token" do
      expect(subject).to receive(:env).once.and_return({gh_access_token: "ABC123"})
      subject.github_access_token
      expect(subject.github_access_token).to eq("ABC123")
    end
  end

  describe "#github_headers" do
    it "should memoize the GitHub API headers" do
      expected_headers = { "Authorization" => "token ABC123",
                          "Content-Type" => "application/json",
                          "Accept" => "application/vnd.github.v3+json" }

      expect(subject).to receive(:github_access_token).once.and_return("ABC123")
      subject.github_headers
      expect(subject.github_headers).to eq(expected_headers)
    end
  end

  describe "#issue" do
    it "should call proper issue using the Octokit client" do
      expect_any_instance_of(Octokit::Client).to receive(:issue).once.with("openjournals/buffy", 5).and_return("issue")
      subject.issue
      subject.issue
    end
  end

  describe "#issue_body" do
    it "should get body from context if present" do
      subject.context.issue_body = "Body Issue in Context"

      expect(subject).to_not receive(:issue)
      expect(subject.issue_body).to eq("Body Issue in Context")
    end

    it "should get body calling #issue if not available in context" do
      subject.context.issue_body = nil

      expect(subject).to receive(:issue).once.and_return(OpenStruct.new(body: "Body from calling issue"))
      expect(subject.issue_body).to eq("Body from calling issue")
    end
  end

  describe "#template_url" do
    it "should get the download url of a template" do
      expected_url = "https://github.com/openjournals/buffy/templates/test_message.md"
      expect_any_instance_of(Octokit::Client).to receive(:contents).once.and_return(OpenStruct.new(download_url: expected_url))

      expect(subject.template_url("test_message.md")).to eq(expected_url)
    end

    it "should get the contents for the right template file" do
      expected_path = Pathname.new "#{subject.default_settings[:templates_path]}/test_message.md"
      response = OpenStruct.new(download_url: "")
      expect_any_instance_of(Octokit::Client).to receive(:contents).once.with("openjournals/buffy", path: expected_path).and_return(response)

      subject.template_url("test_message.md")
    end
  end

  describe "#bg_respond" do
    it "should add comment to github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:add_comment).once.with("openjournals/buffy", 5, "comment!")
      subject.bg_respond("comment!")
    end
  end

  describe "#label_issue" do
    it "should add labels to github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:add_labels_to_an_issue).once.with("openjournals/buffy", 5, ["reviewed"])
      subject.label_issue(["reviewed"])
    end
  end

  describe "#unlabel_issue" do
    it "should remove label from github issue" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_label).once.with("openjournals/buffy", 5, "pending-review")
      subject.unlabel_issue("pending-review")
    end
  end

  describe "#issue_labels" do
    it "should return the labels names from github issue" do
      labels = [{id:1, name: "A"}, {id:21, name: "J"}]
      expect_any_instance_of(Octokit::Client).to receive(:labels_for_issue).once.with("openjournals/buffy", 5).and_return(labels)
      expect(subject.issue_labels).to eq(["A", "J"])
    end
  end

  describe "#issue_comment" do
    it "should get issue comment from github" do
      expect_any_instance_of(Octokit::Client).to receive(:issue_comment).once.with("openjournals/buffy", 12345).and_return("Comment")
      expect(subject.issue_comment(12345)).to eq("Comment")
    end
  end

  describe "#update_comment" do
    it "should update issue comment with received content" do
      expect_any_instance_of(Octokit::Client).to receive(:update_comment).once.with("openjournals/buffy", 12345, "New reviewer checklist here")
      subject.update_comment(12345, "New reviewer checklist here")
    end
  end

  describe "#update_issue" do
    it "should update github issue with received options" do
      expect_any_instance_of(Octokit::Client).to receive(:update_issue).once.with("openjournals/buffy", 5, { body: "new body"})
      subject.update_issue({body: "new body"})
    end
  end

  describe "#close_issue" do
    it "should close a github issue with received options" do
      expect_any_instance_of(Octokit::Client).to receive(:close_issue).once.with("openjournals/buffy", 5, { labels: "rejected" })
      subject.close_issue({ labels: "rejected" })
    end
  end

  describe "#is_collaborator?" do
    it "should be true if user is a collaborator" do
      expect_any_instance_of(Octokit::Client).to receive(:collaborator?).twice.with("openjournals/buffy", "xuanxu").and_return(true)
      expect(subject.is_collaborator?("@xuanxu")).to eq(true)
      expect(subject.is_collaborator?("xuanxu")).to eq(true)
    end

    it "should be false if user is not a collaborator" do
      expect_any_instance_of(Octokit::Client).to receive(:collaborator?).twice.with("openjournals/buffy", "xuanxu").and_return(false)
      expect(subject.is_collaborator?("@xuanxu")).to eq(false)
      expect(subject.is_collaborator?("xuanxu")).to eq(false)
    end
  end

  describe "#is_invited?" do
    before do
      invitations = [OpenStruct.new(invitee: OpenStruct.new(login: 'Faith')), OpenStruct.new(invitee: OpenStruct.new(login: 'Buffy'))]
      allow_any_instance_of(Octokit::Client).to receive(:repository_invitations).with("openjournals/buffy").and_return(invitations)
    end

    it "should be true if user has a pending invitation" do
      expect(subject.is_invited?("@buffy")).to eq(true)
      expect(subject.is_invited?("buffy")).to eq(true)
    end

    it "should be false if user has not a pending invitation" do
      expect(subject.is_invited?("drusilla")).to eq(false)
    end
  end

  describe "#add_collaborator" do
    it "should add the user to the repo's collaborators" do
      expect_any_instance_of(Octokit::Client).to receive(:add_collaborator).once.with("openjournals/buffy", "xuanxu")
      subject.add_collaborator("xuanxu")
    end

    it "should use the user's login" do
      expect_any_instance_of(Octokit::Client).to receive(:add_collaborator).once.with("openjournals/buffy", "xuanxu")
      subject.add_collaborator("@xuanxu")
    end
  end

  describe "#remove_collaborator" do
    it "should remove the user to the repo's collaborators" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_collaborator).once.with("openjournals/buffy", "xuanxu")
      subject.remove_collaborator("xuanxu")
    end

    it "should use the user's login" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_collaborator).once.with("openjournals/buffy", "xuanxu")
      subject.remove_collaborator("@xuanxu")
    end
  end

  describe "#add_assignee" do
    it "should add the user to the repo's assignees list" do
      expect_any_instance_of(Octokit::Client).to receive(:add_assignees).once.with("openjournals/buffy", 5, ["xuanxu"])
      subject.add_assignee("xuanxu")
    end

    it "should use the user's login" do
      expect_any_instance_of(Octokit::Client).to receive(:add_assignees).once.with("openjournals/buffy", 5, ["xuanxu"])
      subject.add_assignee("@xuanxu")
    end
  end

  describe "#remove_assignee" do
    it "should remove the user from the repo's assignees list" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_assignees).once.with("openjournals/buffy", 5, ["xuanxu"])
      subject.remove_assignee("xuanxu")
    end

    it "should use the user's login" do
      expect_any_instance_of(Octokit::Client).to receive(:remove_assignees).once.with("openjournals/buffy", 5, ["xuanxu"])
      subject.remove_assignee("@xuanxu")
    end
  end

  describe "#can_be_assignee?" do
    it "should check if user can be an assignee of the repo" do
      expect_any_instance_of(Octokit::Client).to receive(:check_assignee).once.with("openjournals/buffy", "buffy")
      subject.can_be_assignee?("buffy")
    end
  end

  describe "#get_user" do
    it "should call GItHub API to get user information" do
      expect_any_instance_of(Octokit::Client).to receive(:user).once.with("tester").and_return("API response")
      expect(subject.get_user("tester")).to eq("API response")
    end

    it "should be nil if user can't be found" do
      expect_any_instance_of(Octokit::Client).to receive(:user).with("nouser").and_raise(Octokit::NotFound)
      expect(subject.logger).to_not receive(:warn)
      subject.get_user("nouser")
    end

    it "should be nil if token is invalid" do
      expect_any_instance_of(Octokit::Client).to receive(:user).with("whatever").and_raise(Octokit::Unauthorized)
      expect(subject.logger).to receive(:warn).with("Error calling GitHub API! Bad credentials: TOKEN is invalid")
      subject.get_user("whatever")
    end

    it "should be nil if empty username" do
      expect(subject.get_user(nil)).to be_nil
      expect(subject.get_user("")).to be_nil
      expect(subject.get_user("     ")).to be_nil
    end
  end

  describe "#add_new_team" do
    context "with valid permissions" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_team).
                                                  with("openjournals", {name: "superusers", privacy: "closed"}).
                                                  and_return({status: "201"})
      end

      it "should create the team and return true" do
        expect(subject.add_new_team("openjournals/superusers")).to be_truthy
      end
    end

    context "with invalid permissions" do
      before do
        allow_any_instance_of(Octokit::Client).to receive(:create_team).and_raise(Octokit::Forbidden)
        allow(subject.logger).to receive(:warn)
      end

      it "should return false" do
        expect(subject.add_new_team("openjournals/superusers")).to be_falsy
      end

      it "should log a warning" do
        expect(subject.logger).to receive(:warn).with("Error trying to create team openjournals/superusers: Octokit::Forbidden")
        subject.add_new_team("openjournals/superusers")
      end
    end
  end

  describe "#invite_user_to_team" do
    it "should be false if user can't be found" do
      expect(subject).to receive(:get_user).with("nouser").and_return(nil)
      expect(subject.invite_user_to_team("nouser", "my-teams")).to be_falsy
    end

    it "should be false if team does not exist" do
      expect_any_instance_of(Octokit::Client).to receive(:user).with("user42").and_return(double(id: 33))
      expect(subject).to receive(:api_team_id).and_return(nil)
      expect(subject).to receive(:add_new_team).and_return(nil)

      expect(subject.invite_user_to_team("@user42", "openjournals/superusers")).to be_falsy
    end

    it "should be false if can't create team" do
      expect_any_instance_of(Octokit::Client).to receive(:user).and_return(double(id: 33))
      expect(subject).to receive(:api_team_id).and_return(nil)
      allow_any_instance_of(Octokit::Client).to receive(:create_team).and_return(false)

      expect(subject.invite_user_to_team("user42", "openjournals/superusers")).to be_falsy
    end

    it "should try to create team if it does not exist" do
      expect_any_instance_of(Octokit::Client).to receive(:user).and_return(double(id: 33))
      expect(subject).to receive(:api_team_id).and_return(nil)
      expect(subject).to receive(:add_new_team).with("openjournals/superusers").and_return(double(id: 3333))
      expect_any_instance_of(Octokit::Client).to receive(:org_member?).and_return(false)
      expect(Faraday).to receive(:post).and_return(double(status: 200))

      subject.invite_user_to_team("user42", "openjournals/superusers")
    end

    describe "when user is not a member of the organization" do
      it "should be false if invitation can not be created" do
        expect_any_instance_of(Octokit::Client).to receive(:user).and_return(double(id: 33))
        expect(subject).to receive(:api_team_id).with("openjournals/superusers").and_return(1234)
        expect_any_instance_of(Octokit::Client).to receive(:org_member?).and_return(false)
        expect(Faraday).to receive(:post).and_return(double(status: 403))

        expect(subject.invite_user_to_team("user42", "openjournals/superusers")).to be_falsy
      end

      it "should be true when invitation is created" do
        expect_any_instance_of(Octokit::Client).to receive(:user).and_return(double(id: 33))
        expect(subject).to receive(:api_team_id).with("openjournals/superusers").and_return(1234)
        expect_any_instance_of(Octokit::Client).to receive(:org_member?).and_return(false)
        expect(Faraday).to receive(:post).and_return(double(status: 201))

        expect(subject.invite_user_to_team("user42", "openjournals/superusers")).to be_truthy
      end
    end

    describe "when user is already a member of the organization" do
      before { @expected_url = "https://api.github.com/orgs/openjournals/teams/superusers/memberships/user42" }

      it "should be false if user can't be added to the team" do
        expect_any_instance_of(Octokit::Client).to receive(:user).and_return(double(id: 33))
        expect(subject).to receive(:api_team_id).with("openjournals/superusers").and_return(1234)
        expect_any_instance_of(Octokit::Client).to receive(:org_member?).and_return(true)
        expect(Faraday).to receive(:put).with(@expected_url, nil, subject.github_headers).and_return(double(status: 403))

        expect(subject.invite_user_to_team("user42", "openjournals/superusers")).to be_falsy
      end

      it "should be true when user is added to the team" do
        expect_any_instance_of(Octokit::Client).to receive(:user).and_return(double(id: 33))
        expect(subject).to receive(:api_team_id).with("openjournals/superusers").and_return(1234)
        expect_any_instance_of(Octokit::Client).to receive(:org_member?).and_return(true)
        expect(Faraday).to receive(:put).with(@expected_url, nil, subject.github_headers).and_return(double(status: 201))

        expect(subject.invite_user_to_team("user42", "openjournals/superusers")).to be_truthy
      end
    end
  end

  describe "#trigger_workflow" do
    it "should be false if missing repo or workflow" do
      expect(subject.trigger_workflow(nil, "action.yml")).to be_falsy
      expect(subject.trigger_workflow("openjournals/buffy", nil)).to be_falsy
    end

    it "should be false if API call is not successful" do
      expect(Faraday).to receive(:post).and_return(double(status: 401, body: "User Unauthorized"))
      expect(subject.logger).to receive(:warn).with("Error triggering workflow action.yml at openjournals/buffy: ")
      expect(subject.logger).to receive(:warn).with("   Response 401: User Unauthorized")

      expect(subject.trigger_workflow("openjournals/buffy", "action.yml")).to be_falsy
    end

    it "should call Actions API with default params" do
      expected_url = "https://api.github.com/repos/openjournals/buffy/actions/workflows/test-action.yml/dispatches"
      expected_params = { inputs: {}, ref: "main" }.to_json
      expected_headers = subject.github_headers

      expect(Faraday).to receive(:post).with(expected_url, expected_params, expected_headers).and_return(double(status: 204))
      expect(subject.trigger_workflow("openjournals/buffy", "test-action.yml")).to be_truthy
    end

    it "should call Actions API with custom params" do
      expected_url = "https://api.github.com/repos/openjournals/buffy/actions/workflows/test-action.yml/dispatches"
      test_inputs = { repo: "astropy/stars", branch: "article", "paper-path": "docs/paper.md" }
      expected_params = { inputs: test_inputs, ref: "v1.0" }
      expected_headers = subject.github_headers

      expect(Faraday).to receive(:post).with(expected_url, expected_params.to_json, expected_headers).and_return(double(status: 204))
      expect(subject.trigger_workflow("openjournals/buffy", "test-action.yml", test_inputs, "v1.0")).to be_truthy
    end
  end

  describe "#api_team_id" do
    context "with valid API access" do
      before do
        teams = [{name: "Editors", id: 372411, description: ""}, {name: "Bots!", id: 111001, slug: "bots"}]
        expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.and_return(teams)
      end

      it "should return team's id if the team exists" do
        expect(subject.api_team_id("openjournals/editors")).to eq(372411)
      end

      it "should find team by slug" do
        expect(subject.api_team_id("openjournals/bots")).to eq(111001)
      end

      it "should return nil if the team doesn't exists" do
        expect(subject.api_team_id("openjournals/nonexistent")).to be_nil
      end
    end

    it "should raise a configuration error for teams with wrong name" do
      expect {
        subject.api_team_id("wrong-name")
      }.to raise_error "Configuration Error: Invalid team name: wrong-name"
    end

    it "should raise a configuration error if there's not access to the organization" do
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.with("buffy").and_raise(Octokit::Forbidden)

      expect {
        subject.api_team_id("buffy/whatever")
      }.to raise_error "Configuration Error: No API access to organization: buffy"
    end
  end

  describe "#api_team_members" do
    before do
      members = [double(login: "user1"), double(login: "user2")]
      allow_any_instance_of(Octokit::Client).to receive(:team_members).with(1111).and_return(members)
      allow(subject).to receive(:api_team_id).with("org/team_test").and_return(1111)
    end

    it "should accept a team id" do
      expect(subject.api_team_members(1111)).to eq(["user1", "user2"])
    end

    it "should accept a team name" do
      expect(subject.api_team_members("org/team_test")).to eq(["user1", "user2"])
    end

    it "should return empty list if the team doesn't exists" do
      expect(subject.api_team_members(nil)).to eq([])
    end
  end

  describe "#user_in_authorized_teams?" do
    it "should return true if user is member of any authorized team" do
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(11, "sender").and_return(true)
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(22, "sender")
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(33, "sender")

      expect(subject.user_in_authorized_teams?("sender")).to be_truthy
    end

    it "should return false if user is not member of any authorized team" do
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(11, "sender").and_return(false)
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).never.with(22, "sender")
      expect_any_instance_of(Octokit::Client).to receive(:team_member?).once.with(33, "sender").and_return(false)

      expect(subject.user_in_authorized_teams?("sender")).to be_falsey
    end
  end

  describe "#issue_url" do
    it "should return the url of the repo's current issue page" do
      expected_url = "https://github.com/openjournals/buffy/issues/5"
      expect(subject.context.repo).to eq("openjournals/buffy")
      expect(subject.context.issue_id).to eq(5)
      expect(subject.issue_url).to eq(expected_url)
    end
  end

  describe "#invitations_url" do
    it "should return the url of the repo's invitations page" do
      expected_url = "https://github.com/openjournals/buffy/invitations"
      expect(subject.invitations_url).to eq(expected_url)
    end
  end

  describe "#comment_url" do
    before do
      subject.context[:comment_id] = "3333333"
    end

    it "should return the url of the comment in the context's issue" do
      expected_url = "https://github.com/openjournals/buffy/issues/5#issuecomment-1031221716"
      expect(subject.comment_url("1031221716")).to eq(expected_url)
      expect(subject.comment_url(1031221716)).to eq(expected_url)
    end

    it "should return the url of the context's comment if no comment_id" do
      expected_url = "https://github.com/openjournals/buffy/issues/5#issuecomment-3333333"
      expect(subject.comment_url).to eq(expected_url)
    end
  end

  describe ".get_team_ids" do
    it "should convert all team entries to ids" do
      config = { teams: { editors: 11, eics: "openjournals/eics", nonexistent: "openjournals/nope" }, env: {gh_access_token: "ABC123"}}
      expect(Octokit::Client).to receive(:new).with(access_token: "ABC123", auto_paginate: true).and_return(Octokit::Client.new)
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).twice.and_return([{name: "eics", id: 42}])

      expected_response = { editors: 11, eics: 42, nonexistent: nil }
      expect(Responder.get_team_ids(config)). to eq(expected_response)
    end

    it "should find teams by slug" do
      config = { teams: { the_bots: "openjournals/bots" }, env: {gh_access_token: "ABC123"}}
      expect(Octokit::Client).to receive(:new).with(access_token: "ABC123", auto_paginate: true).and_return(Octokit::Client.new)
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.and_return([{name: "Rob0tz", id: 111001, slug: "bots"}])

      expected_response = { the_bots: 111001 }
      expect(Responder.get_team_ids(config)). to eq(expected_response)
    end

    it "should raise a configuration error for teams with wrong name" do
      config = { teams: { editors: 11, nonexistent: "wrong-name" } }

      expect {
        Responder.get_team_ids(config)
      }.to raise_error "Configuration Error: Invalid team name: wrong-name"
    end

    it "should raise a configuration error if there's not access to the organization" do
      config = { teams: { the_bots: "openjournals/bots" }, env: {gh_access_token: "ABC123"}}
      expect(Octokit::Client).to receive(:new).with(access_token: "ABC123", auto_paginate: true).and_return(Octokit::Client.new)
      expect_any_instance_of(Octokit::Client).to receive(:organization_teams).once.with("openjournals").and_raise(Octokit::Forbidden)

      expect {
        Responder.get_team_ids(config)
      }.to raise_error "Configuration Error: No API access to organization: openjournals"
    end
  end

  describe "#user_login" do
    it "should remove the @ from a username" do
      expect(subject.user_login("@buffy")).to eq("buffy")
    end

    it "should strip the username" do
      expect(subject.user_login(" buffy  ")).to eq("buffy")
    end
  end

  describe "#username?" do
    it "should be true if username starts with @" do
      expect(subject.username?("@buffy")).to be_truthy
    end

    it "should be false otherwise" do
      expect(subject.username?("buffy")).to be_falsey
    end
  end

end