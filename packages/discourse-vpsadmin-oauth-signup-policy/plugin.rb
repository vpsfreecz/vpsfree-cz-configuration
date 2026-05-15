# frozen_string_literal: true

# name: discourse-vpsadmin-oauth-signup-policy
# about: Allow new accounts only after vpsAdmin OAuth authentication
# version: 0.1
# authors: vpsFree.cz

module ::VpsAdminOauthSignupPolicy
  def create
    if vpsadmin_local_registration?
      return fail_with('login.new_registrations_disabled')
    end

    super
  end

  private

  def vpsadmin_local_registration?
    return false if current_user&.admin?

    auth = server_session[:authentication]
    return true unless auth.is_a?(Hash)

    authenticator_name = auth[:authenticator_name] || auth['authenticator_name']

    authenticator_name != 'oauth2_basic'
  end
end

after_initialize do
  ::UsersController.prepend(::VpsAdminOauthSignupPolicy)
end
