module Authorizations

  def authorized_teams
    @authorized_teams ||= begin
      teams_ids_or_names = []
      case params[:only]
      when String
        teams_ids_or_names << @teams[params[:only]]
      when Array
        params[:only].each { |team_name| teams_ids_or_names << @teams[team_name] }
      end
      teams_ids_or_names
    end
  end

  def authorized_users
    @authorized_users ||= begin
      user_handles = []
      authorized_teams.each do |team|
        if team.is_a?(Array)
          user_handles += team
        end
      end
      user_handles.uniq
    end
  end

  def authorized_team_ids
    @authorized_team_ids ||= begin
      team_ids = []
      authorized_teams.each do |team_id_or_name|
        case team_id_or_name
        when Integer
          team_ids << team_id_or_name
        when String
          found_team_id = team_id(team_id_or_name)
          team_ids << found_team_id unless found_team_id.nil?
        end
      end
      team_ids.uniq
    end
  end

  def authorized_team_names
    @authorized_team_names ||= begin
      team_names = []
      case params[:only]
      when String
        team_names << params[:only]
      when Array
        params[:only].each { |team_name| team_names << team_name }
      end
      team_names
    end
  end

  def authorized_teams_sentence
    @authorized_teams_sentence ||= begin
      if authorized_team_names.size == 1
        authorized_team_names[0]
      elsif authorized_team_names.size > 1
        "#{authorized_team_names[0...-1] * ', '} and #{authorized_team_names[-1]}"
      else
        ""
      end
    end
  end

  def user_authorized?(user_login)
    authorized_users.include?(user_login) || user_in_authorized_teams?(user_login)
  end

end
