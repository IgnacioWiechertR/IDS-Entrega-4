# B5: Active Storage's own routes stay undrawn in every environment.
# `config.active_storage.draw_routes = false` (config/application.rb) is copied to
# ActiveStorage.draw_routes in an after_initialize hook. In production the routes are
# drawn eagerly before that hook, so the framework routes were drawn anyway and their
# `rails_direct_uploads` name collided with the closed endpoint in config/routes.rb,
# which stopped the app from booting. Setting it here applies it before the routes load.
ActiveStorage.draw_routes = false
