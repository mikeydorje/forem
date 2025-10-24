module Api
  module V1
    class TestNotificationsController < ApplicationController
      skip_before_action :verify_authenticity_token
      
      def create
        # Just return a notification payload for the app to display locally
        render json: {
          notification: {
            title: "Test from Rails!",
            body: "This is a local notification triggered by the server",
            data: {
              url: "/notifications",
              type: "test"
            }
          }
        }
      end
    end
  end
end
