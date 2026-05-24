require 'xcodeproj'

project_path = 'macosApp/macosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target    = project.targets.find { |t| t.name == 'macosApp' }
widget_target = project.targets.find { |t| t.name == 'SalaryWidget' }

app_target.build_configurations.each do |config|
  config.build_settings['ENABLE_APP_SANDBOX']     = 'YES'
  config.build_settings['CODE_SIGN_STYLE']        = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'macosApp/macosApp.entitlements'
end

widget_target.build_configurations.each do |config|
  config.build_settings['ENABLE_APP_SANDBOX']     = 'YES'
  config.build_settings['CODE_SIGN_STYLE']        = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'SalaryWidget/SalaryWidget.entitlements'
end

project.save
puts "Done: sandbox re-enabled, automatic signing set"
