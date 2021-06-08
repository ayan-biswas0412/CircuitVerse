class LtiController < ApplicationController
  before_action :set_group, only: %i[launch]
  after_action :allow_iframe, only: %i[launch]
  
  def launch
    #If set, then hide the header and footer
    session[:isLTI]=true
    
    require 'oauth/request_proxy/action_controller_request'
    
    if @group.present?
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
      email_from_lms = params[:lis_person_contact_email_primary] ## caches the email from the LMS
      lms_type = params[:tool_consumer_info_product_family_code] ## caches type of lms like moodle/canvas
      course_title_from_lms = params[:context_title] ## caches the course titile from lms

      # implement the logic of fetch group by token and auth user without passsword
      # get group from token  and we have to make a permanent toekn per group onClick
      # if user is member of group then sign_in(:user) else send an email
      user = User.find_by(email: email_from_lms)
      if user.present?
        sign_in(user)
        lms_auth_success_notice = 'Logged in as '+email_from_lms+' via '+lms_type+' for course '+course_title_from_lms
        redirect_to group_path(@group), notice: lms_auth_success_notice
      end
      
      # if auth_success send to group page
      ##checking need to be done if the user is part of the group or not
      #redirect_to "/groups/#{@group.id}"  ## ideally to group page
      
      
      
      
      
    end
  end

  def allow_iframe
    response.headers.except! 'X-Frame-Options'
  end

  private
    def set_group
      ## query db and check moodle_key is equal to group where @group.lti_token_key == moodle_key
      @group = Group.select(:id,:lti_token).find_by(lti_token_key: params[:oauth_consumer_key])
    end
end
