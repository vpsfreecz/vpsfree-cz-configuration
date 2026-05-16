# frozen_string_literal: true

# name: discourse-oauth-signup-policy
# about: Allow new accounts only after approved OAuth authentication
# version: 0.1
# authors: vpsFree.cz

module ::OauthSignupPolicy
  ALLOWED_AUTHENTICATORS = %w[
    github
    oauth2_basic
  ].freeze

  def create
    if local_registration?
      return fail_with('login.new_registrations_disabled')
    end

    super
  end

  private

  def local_registration?
    return false if current_user&.admin?

    auth = server_session[:authentication]
    return true unless auth.is_a?(Hash)

    authenticator_name = auth[:authenticator_name] || auth['authenticator_name']

    !ALLOWED_AUTHENTICATORS.include?(authenticator_name)
  end
end

after_initialize do
  ::UsersController.prepend(::OauthSignupPolicy)
end
