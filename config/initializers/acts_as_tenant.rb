# Jobs keep the university that was active when they were enqueued.
require "acts_as_tenant/sidekiq"

# A query on a university-scoped model without an active university raises instead of
# returning rows from both universities.
ActsAsTenant.configure do |config|
  config.require_tenant = true
end
