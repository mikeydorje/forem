require "net/http"
require "json"
require "googleauth"

module Push
  class FcmV1Client
    SCOPE = "https://www.googleapis.com/auth/firebase.messaging".freeze

    def self.send(token:, title:, body:, data: {}, dry_run: false)
      if dry_run
        Rails.logger.info("[Push::FcmV1Client] DRY RUN: Sending to #{token} - #{title}: #{body}")
        return { status: 200, body: "Dry Run" }
      end

      project_id = ENV["FCM_PROJECT_ID"]
      unless project_id
        Rails.logger.error("[Push::FcmV1Client] Missing FCM_PROJECT_ID")
        return { status: 500, body: "Missing FCM_PROJECT_ID" }
      end

      new(project_id: project_id).send_to_token(token: token, title: title, body: body, data: data)
    end

    def initialize(project_id:, service_account_path: ENV["GOOGLE_APPLICATION_CREDENTIALS"])
      @project_id = project_id
      @service_account_path = service_account_path
    end

    def send_to_token(token:, title:, body:, data: {})
      access_token = fetch_access_token
      unless access_token
        Rails.logger.error("[Push::FcmV1Client] Could not obtain access token")
        return { status: 401, body: "Could not obtain access token" }
      end

      url = URI("https://fcm.googleapis.com/v1/projects/#{@project_id}/messages:send")
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true

      message = {
        token: token,
        notification: { title: title, body: body },
        data: data.transform_keys(&:to_s),
        android: { priority: "high" }
      }

      req = Net::HTTP::Post.new(url)
      req["Authorization"] = "Bearer #{access_token}"
      req["Content-Type"] = "application/json"
      req.body = { message: message }.to_json

      res = http.request(req)
      Rails.logger.info("[Push::FcmV1Client] Response: #{res.code} #{res.body}")
      { status: res.code.to_i, body: res.body }
    end

    private

    def fetch_access_token
      if @service_account_path && File.exist?(@service_account_path)
        authorizer = Google::Auth::ServiceAccountCredentials.make_creds(
          json_key_io: File.open(@service_account_path),
          scope: SCOPE
        )
      else
        # Fallback to default credentials (e.g. from ENV or metadata server)
        authorizer = Google::Auth.get_application_default([SCOPE])
      end
      authorizer.fetch_access_token!
      authorizer.access_token
    rescue => e
      Rails.logger.error("FCM auth error: #{e.message}") if defined?(Rails)
      nil
    end
  end
end
