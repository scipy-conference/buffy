require_relative "./spec_helper.rb"

describe "Actions" do

  subject do
    Responder.new({}, {})
  end

  before do
    disable_github_calls_for(subject)
  end

  describe "#respond" do
    it "should call bg_respond" do
      expect(subject).to receive(:bg_respond).once.with("New message")
      subject.respond("New message")
    end
  end

  describe "#update_body" do
    before do
      @initial_body = "... <before> Here! <after> ..."
      @expected_new_body = "... <before> New content! <after> ..."
      @context = OpenStruct.new(issue_body: @initial_body)

      allow(subject).to receive(:context).and_return(@context)
      expect(subject).to receive(:update_issue).once.with({body: @expected_new_body})

    end

    it "should call update_issue on new body" do
      subject.update_body("<before>", "<after>" ," New content! ")
    end

    it "should update @body_issue" do
      expect(subject.issue_body).to eq(@initial_body)
      subject.update_body("<before>", "<after>" ," New content! ")
      expect(subject.issue_body).to eq(@expected_new_body)
    end
  end

  describe "#append_to_body" do
    before do
      @initial_body = "Hi <before> there! <after> this is the end"
      @context = OpenStruct.new(issue_body: @initial_body)
      @expected_new_body = "Hi <before> there! <after> this is the end\nNow this is the new end"

      allow(subject).to receive(:context).and_return(@context)
      expect(subject).to receive(:update_issue).once.with({body: @expected_new_body})
    end

    it "should call update_issue on new body" do
      subject.append_to_body("\nNow this is the new end")
    end

    it "should update @body_issue" do
      expect(subject.issue_body).to eq(@initial_body)
      subject.append_to_body("\nNow this is the new end")
      expect(subject.issue_body).to eq(@expected_new_body)
    end
  end

  describe "#prepend_to_body" do
    before do
      @initial_body = "Hi <before> there! <after> this is the end"
      @context = OpenStruct.new(issue_body: @initial_body)
      @expected_new_body = "Now this is the start\nHi <before> there! <after> this is the end"

      allow(subject).to receive(:context).and_return(@context)
      expect(subject).to receive(:update_issue).once.with({body: @expected_new_body})
    end

    it "should call update_issue on new body" do
      subject.prepend_to_body("Now this is the start\n")
    end

    it "should update @body_issue" do
      expect(subject.issue_body).to eq(@initial_body)
      subject.prepend_to_body("Now this is the start\n")
      expect(subject.issue_body).to eq(@expected_new_body)
    end
  end

  describe "#new_body" do
    before do
      @initial_body = "Hi <before> there! <after> this is the end"
      @context = OpenStruct.new(issue_body: @initial_body)
      @expected_new_body = "This is the new body"

      allow(subject).to receive(:context).and_return(@context)
      expect(subject).to receive(:update_issue).once.with({body: @expected_new_body})
    end

    it "should call update_issue on new body" do
      subject.new_body("This is the new body")
    end

    it "should update @body_issue" do
      expect(subject.issue_body).to eq(@initial_body)
      subject.new_body("This is the new body")
      expect(subject.issue_body).to eq(@expected_new_body)
    end
  end

  describe "#update_or_add_value" do
    before do
      @initial_body = "Hi <!--x--><!--end-x--> this is the body"
      @context = OpenStruct.new(issue_body: @initial_body)

      allow(subject).to receive(:context).and_return(@context)
    end

    it "should update value if placeholder exists" do
      expected_new_body = "Hi <!--x-->test<!--end-x--> this is the body"
      expect(subject).to receive(:update_issue).once.with({body: expected_new_body})
      subject.update_or_add_value("x", "test")
    end

    it "should append value" do
      expected_new_body = @initial_body + "\n**Y:** <!--y-->test<!--end-y-->"
      expect(subject).to receive(:update_issue).once.with({body: expected_new_body})
      subject.update_or_add_value("y", "test")
    end

    it "should prepend value" do
      expected_new_body = "**Y:** <!--y-->test<!--end-y-->\n" + @initial_body
      expect(subject).to receive(:update_issue).once.with({body: expected_new_body})
      subject.update_or_add_value("y", "test", append: false)
    end

    it "should hide value (no heading)" do
      expected_new_body = @initial_body + "\n<!--y-->test<!--end-y-->"
      expect(subject).to receive(:update_issue).once.with({body: expected_new_body})
      subject.update_or_add_value("y", "test", hide: true)
    end

    it "should use custom heading" do
      expected_new_body = @initial_body + "\n**Y Axis:** <!--y-->test<!--end-y-->"
      expect(subject).to receive(:update_issue).once.with({body: expected_new_body})
      subject.update_or_add_value("y", "test", heading: "Y Axis")
    end
  end

  describe "#issue_body_has?" do
    before do
      @body = "Hi <!--value33--> there! <!--end-value33--> <!--no-value--><!--end-no-value--> Bye"
      @context = OpenStruct.new(issue_body: @body)

      allow(subject).to receive(:context).and_return(@context)
    end

    it "is true if value is marked with HTML comments in the body" do
      expect(subject.issue_body_has?("value33")).to be_truthy
    end

    it "is true if value is empty but present" do
      expect(subject.issue_body_has?("no-value")).to be_truthy
    end

    it "is false if value is not present in the body of the issue" do
      expect(subject.issue_body_has?("other-value")).to be_falsy
    end
  end

  describe "#update_value" do
    before do
      @body = "Hi <!--value33-->33<!--end-value33-->"
      @context = OpenStruct.new(issue_body: @body)

      allow(subject).to receive(:context).and_return(@context)
    end

    it "updates value in body" do
      expect(subject).to receive(:update_body).once.with("<!--value33-->", "<!--end-value33-->", "42")
      expect(subject.update_value("value33", "42")).to eq(true)
    end

    it "is false if no value placeholder found in body" do
      expect(subject).to_not receive(:update_body)
      expect(subject.update_value("value42", "42")).to eq(false)
    end
  end

  describe "#update_list" do
    before do
      @body = "Hi <!--letters-list-->abc<!--end-letters-list-->"
      @context = OpenStruct.new(issue_body: @body)

      allow(subject).to receive(:context).and_return(@context)
    end

    it "updates value in body" do
      expect(subject).to receive(:update_body).once.with("<!--letters-list-->", "<!--end-letters-list-->", "xyz")
      expect(subject.update_list("letters", "xyz")).to eq(true)
    end

    it "is false if no value placeholder found in body" do
      expect(subject).to_not receive(:update_body)
      expect(subject.update_list("numbers", "4321")).to eq(false)
    end
  end

  describe "#delete_from_body" do
    before do
      @initial_body = "Intro <before> Here!\n <after> Final"
      @expected_new_body = "Intro <before><after> Final"
      @context = OpenStruct.new(issue_body: @initial_body)
      allow(subject).to receive(:context).and_return(@context)
    end

    it "should not remove marks by default and update @body_issue" do
      expect(subject.issue_body).to eq(@initial_body)
      expect(subject).to receive(:update_issue).once.with({body: @expected_new_body})
      subject.delete_from_body("<before>", "<after>")
      expect(subject.issue_body).to eq(@expected_new_body)
    end

    it "should call update_issue on new body removing block content" do
      expect(subject).to receive(:update_issue).once.with({body: @expected_new_body})
      subject.delete_from_body("<before>", "<after>", false)
    end

    it "should call update_issue on new body removing block and marks" do
      expected_new_body = "Intro  Final"

      expect(subject).to receive(:update_issue).once.with({body: expected_new_body})
      subject.delete_from_body("<before>", "<after>", true)
    end
  end

  describe "#read_from_body" do
    before { allow(subject).to receive(:issue_body).and_return("... <before> Here! <after> ...") }
    it "should return stripped text between marks" do
      expected_text = "Here!"

      expect(subject.read_from_body("<before>", "<after>")).to eq expected_text
    end

    it "should return empty string if nothing matches" do
      expected_text = ""

      expect(subject.read_from_body("<Hey>", "<after>")).to eq expected_text
    end
  end

  describe "#read_value_from_body" do
    before { allow(subject).to receive(:issue_body).and_return("... <!--where--> Here! <!--end-where--> ...") }
    it "should return stripped text between HTML comments" do
      expected_text = "Here!"

      expect(subject.read_value_from_body("where")).to eq expected_text
    end

    it "should return empty string if nothing matches" do
      expected_text = ""

      expect(subject.read_value_from_body("nomatch")).to eq expected_text
    end
  end

  describe "#read_values_from_body" do
    before { allow(subject).to receive(:issue_body).and_return("... <!--where--> Here! <!--end-where--> ..." +
                                                               "... <!--who--> You! <!--end-who--> ..." +
                                                               "... <!--when--> Now! <!--end-when--> ...") }
    it "should return stripped list of values between HTML comments" do
      expected_values = ["Here!", "Now!", "You!"]

      expect(subject.read_values_from_body(["where", "when", "who"])).to eq expected_values
    end

    it "should return only existing values" do
      expected_values = ["Here!", "Now!"]

      expect(subject.read_values_from_body(["where", "when", "what"])).to eq expected_values
    end

    it "should accept a single string value" do
      expected_values = ["Here!"]

      expect(subject.read_values_from_body("where")).to eq expected_values
    end
  end

  describe "#value_of_or_default" do
    before { allow(subject).to receive(:issue_body).and_return("... <!--version--> 3.1.2 <!--end-version--> ...\n" +
                                                               "... <!--v--> 0.0.1-alpha <!--end-v--> ...") }
    it "should return stripped text from default value name" do
      expected_text = "3.1.2"

      expect(subject.value_of_or_default(nil, "version")).to eq expected_text
      expect(subject.value_of_or_default("", "version")).to eq expected_text
    end

    it "should return stripped text from value if value name is passed" do
      expected_text = "0.0.1-alpha"

      expect(subject.value_of_or_default("v", "version")).to eq expected_text
      expect(subject.value_of_or_default("v", nil)).to eq expected_text
    end

    it "should return empty string if no matches" do
      expected_text = ""

      expect(subject.value_of_or_default("nomatch", "version")).to eq expected_text
      expect(subject.value_of_or_default(nil, "nomatch")).to eq expected_text
      expect(subject.value_of_or_default(nil, nil)).to eq expected_text
    end
  end

  describe "#replace_assignee" do
    before { disable_github_calls_for(subject) }

    it "should replace assignees if old_assignee & new_assignee are present" do
      expect(subject).to receive(:add_assignee).once.with("@new_editor")
      expect(subject).to receive(:remove_assignee).once.with("@old_editor")
      subject.replace_assignee("@old_editor", "@new_editor")
    end

    it "should not add assignee if new_assignee is blank" do
      expect(subject).to_not receive(:add_assignee)
      expect(subject).to receive(:remove_assignee).twice.with("@old_editor")
      subject.replace_assignee("@old_editor", nil)
      subject.replace_assignee("@old_editor", "")
    end

    it "should not remove assignee if old_assignee is blank" do
      expect(subject).to receive(:add_assignee).twice.with("@new_editor")
      expect(subject).to_not receive(:remove_assignee)
      subject.replace_assignee(nil, "@new_editor")
      subject.replace_assignee("", "@new_editor")
    end
  end

  describe "#invite_user" do
    before do
      allow(subject).to receive(:invitations_url).and_return("../invitations")
    end

    it "should reply if user has a pending invitation" do
      allow(subject).to receive(:is_invited?).and_return(true)
      allow(subject).to receive(:is_collaborator?).and_return(false)
      expected_response = "The reviewer already has a pending invitation.\n\n@buffy please accept the invite here: ../invitations"

      expect(subject).to_not receive(:add_collaborator)
      expect(subject.invite_user("@buffy")).to eq(expected_response)
    end

    it "should reply if user is already a collaborator" do
      allow(subject).to receive(:is_invited?).and_return(false)
      allow(subject).to receive(:is_collaborator?).and_return(true)
      expected_response = "@buffy already has access."

      expect(subject).to_not receive(:add_collaborator)
      expect(subject.invite_user("@buffy")).to eq(expected_response)
    end

    it "should add user as collaborator otherwise" do
      allow(subject).to receive(:is_invited?).and_return(false)
      allow(subject).to receive(:is_collaborator?).and_return(false)
      expect(subject).to receive(:add_collaborator).and_return(true)
      expected_response = "OK, invitation sent!\n\n@buffy please accept the invite here: ../invitations"

      expect(subject.invite_user("@buffy")).to eq(expected_response)
    end

    it "should report when unable to add user as collaborator" do
      allow(subject).to receive(:is_invited?).and_return(false)
      allow(subject).to receive(:is_collaborator?).and_return(false)
      expect(subject).to receive(:add_collaborator).and_return(false)
      expected_response = "It was not possible to invite @buffy"

      expect(subject.invite_user("@buffy")).to eq(expected_response)
    end
  end
end
