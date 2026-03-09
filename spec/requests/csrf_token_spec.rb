require "rails_helper"

RSpec.describe "CSRF Token", type: :request do
  let(:user) { create(:user) }
  let(:article) { create(:article) }

  before do
    sign_in user
    ActionController::Base.allow_forgery_protection = true
  end

  after do
    ActionController::Base.allow_forgery_protection = false
  end

  context "when CSRF token is invalid" do
    it "returns 422 status" do
      post comments_path, params: {
        comment: { body_markdown: "Test comment", commentable_id: article.id, commentable_type: "Article" }
      }, headers: { "X-CSRF-Token" => "invalid_token" }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "increments stats counter" do
      expect(ForemStatsClient).to receive(:increment).with(
        "users.invalid_authenticity_token",
        tags: ["controller_name:comments", "path:/comments"]
      )

      post comments_path, params: {
        comment: { body_markdown: "Test comment", commentable_id: article.id, commentable_type: "Article" }
      }, headers: { "X-CSRF-Token" => "invalid_token" }
    end
  end

  context "when CSRF token is missing" do
    it "returns 422 status" do
      post comments_path, params: {
        comment: { body_markdown: "Test comment", commentable_id: article.id, commentable_type: "Article" }
      }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "increments stats counter" do
      expect(ForemStatsClient).to receive(:increment).with(
        "users.invalid_authenticity_token",
        tags: ["controller_name:comments", "path:/comments"]
      )

      post comments_path, params: {
        comment: { body_markdown: "Test comment", commentable_id: article.id, commentable_type: "Article" }
      }
    end
  end
end
