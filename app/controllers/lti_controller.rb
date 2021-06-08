class LtiController < ApplicationController
  before_action :set_group, only: %i[launch]
  after_action :allow_iframe, only: %i[launch]
  before_action :set_lti_params, only: %i[launch]
  
  def launch
    #If set, then hide the header and footer
    session[:isLTI]=true
    require 'oauth/request_proxy/action_controller_request'
    
    if @group.present?
      #if there is a valid group based for the lti_token_key
      @provider = IMS::LTI::ToolProvider.new(
        params[:oauth_consumer_key], ## moodle_key
        @group.lti_token, ## the group's lti_token
        params
      )

      if not @provider.valid_request?(request)
        render :launch_error, status: 401
        return
      end

      @@launch_params=params;
      # get group from token  and we have to make a permanent toekn per group onClick
      # if user is member of group then sign_in(:user) else send an email
      user = User.find_by(email: @email_from_lms)

      if user.present?
        user_in_group = GroupMember.find_by(user_id:user.id,group_id:@group.id)

        if user_in_group.present? || user.id === @group.mentor_id 
          # if user is a member or mentor of the group then allow authentication
          sign_in(user)
          lms_auth_success_notice = 'Logged in as '+@email_from_lms+' via '+@lms_type+' for course '+@course_title_from_lms
          redirect_to group_path(@group), notice: lms_auth_success_notice # if auth_success send to group page
        else # if the user is not a member of the group then we have to send mail
          render :launch_error, status: 401 #notice has to be given
          return
        end
      else
        # if there is no such user in circuitverse, then we have to send mail
        render :launch_error, status: 401 #notice has to be given
        return
      end
    else
      #if there is no valid group present for the lti_token_key
      render :launch_error, status: 401 #notice has to be given
      return
    end
  end

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end

  private
    def set_group
      ## query db and check moodle_key is equal to group where @group.lti_token_key == moodle_key
      @group = Group.select(:id,:mentor_id,:lti_token).find_by(lti_token_key: params[:oauth_consumer_key])
    end
    
    def set_lti_params
      @email_from_lms = params[:lis_person_contact_email_primary] # the email from the LMS
      @lms_type = params[:tool_consumer_info_product_family_code] # type of lms like moodle/canvas
      @course_title_from_lms = params[:context_title] # the course titile from lms
    end
end
