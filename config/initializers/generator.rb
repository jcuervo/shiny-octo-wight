Rails.application.config.generators do |g|
  g.test_framework :rspec,
    fixtures: true,
    view_specs: false,
    controller_specs: true,
    request_specs: true
  g.template_engine :haml
  g.fixture_replacement :factory_girl, dir: 'spec/factories'
end
