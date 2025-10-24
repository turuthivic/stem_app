ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Mock Redis for testing
require 'sidekiq/testing'
Sidekiq::Testing.fake!
