module V1
  class BaseController < ApplicationController
    before_filter :restrict_access, :strip_attributes

    WHITELIST_IP_ADDRESSES = ['127.0.0.1']

    def user_for_paper_trail
      request.remote_ip
      if whitelisted?
        request.remote_ip
      else
        authenticate_or_request_with_http_token do |token, options|
          token
        end
      end
    end

    def info_for_paper_trail
      { :ip => request.remote_ip, :user_agent => request.user_agent }
    end

    # Strip the action, controller, and format attribute to avoid ActiveModel::MassAssignmentSecurity::Error
    # (Can't mass-assign protected attributes: action, controller, format):
    def strip_attributes
      params.delete(:action)
      params.delete(:controller)
      params.delete(:format)
    end

    private
      def restrict_access
        if whitelisted?
          true
        else
          authenticate_or_request_with_http_token do |token, options|
            ApiKey.exists?(access_token: token)
          end
        end
      end

      def whitelisted?
        WHITELIST_IP_ADDRESSES.include?(request.remote_ip)
      end
  end
end
