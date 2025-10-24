require "test_helper"

class Step1SetupTest < ActionDispatch::IntegrationTest
  test "Rails application starts successfully" do
    assert Rails.application.initialized?
  end

  test "database connection works" do
    assert ActiveRecord::Base.connection.active?
  end

  test "Active Storage is configured" do
    assert_not_nil Rails.application.config.active_storage.service
  end

  test "Sidekiq queue is accessible" do
    require 'sidekiq/api'
    queue = Sidekiq::Queue.new
    assert_equal 0, queue.size
  end

  test "Hotwire gems are available" do
    assert defined?(Turbo)
    assert defined?(Stimulus)
  end

  test "Tailwind CSS is configured" do
    assert File.exist?(Rails.root.join("app/assets/tailwind/application.css"))
  end
end