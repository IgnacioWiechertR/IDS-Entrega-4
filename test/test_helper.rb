ENV["RAILS_ENV"] ||= "test"

# Test coverage (SimpleCov). It must start before the application is loaded. The report is written to
# coverage/index.html at the end of `bin/rails test` (see the README, "Tests y cobertura").
require "simplecov"
SimpleCov.start "rails" do
  enable_coverage :branch
  group "Policies", "app/policies"
  group "Services", "app/services"
end

require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Each parallel worker records its own coverage, and SimpleCov merges them into one report at the end.
    parallelize_setup { |worker| SimpleCov.command_name "#{SimpleCov.command_name}-#{worker}" }
    parallelize_teardown { |_worker| SimpleCov.result }

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # University-scoped models need an active university (A3). Model tests run inside UCV by default and
    # switch with ActsAsTenant.with_tenant when they need IUSA. Integration tests get it from the signed-in
    # user, like the app does.
    setup { ActsAsTenant.current_tenant = universities(:ucv) unless is_a?(ActionDispatch::IntegrationTest) }

    # Add more helper methods to be used by all tests here...
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Inside a request the app sets the university of the signed-in user. Outside one (fixtures and data built by
  # the test) the code runs in UCV by default, like model tests, and switches with ActsAsTenant.with_tenant for
  # IUSA (T7). ActsAsTenant::TestTenantMiddleware (config/environments/test.rb) clears this default during each
  # request, so it never leaks into the app.
  setup { ActsAsTenant.test_tenant = University.find_by(slug: "ucv") }
  teardown { ActsAsTenant.test_tenant = nil }
end
