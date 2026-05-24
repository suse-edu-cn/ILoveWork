require 'xcodeproj'

project_path = 'macosApp/macosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target    = project.targets.find { |t| t.name == 'macosApp' }
widget_target = project.targets.find { |t| t.name == 'SalaryWidget' }

# ── macosApp entitlements ────────────────────────────────────────────────────
app_group = project.main_group.find_subpath('macosApp', false)
unless app_group.files.any? { |f| f.path == 'macosApp.entitlements' }
  ref = app_group.new_reference('macosApp.entitlements')
  ref.last_known_file_type = 'text.plist.entitlements'
end

# ── SalaryWidget entitlements ────────────────────────────────────────────────
widget_group = project.main_group.find_subpath('SalaryWidget', false)
unless widget_group.files.any? { |f| f.path == 'SalaryWidget.entitlements' }
  ref = widget_group.new_reference('SalaryWidget.entitlements')
  ref.last_known_file_type = 'text.plist.entitlements'
end

# ── Re-enable sandbox and set entitlements path ──────────────────────────────
app_target.build_configurations.each do |config|
  config.build_settings['ENABLE_APP_SANDBOX']     = 'YES'
  config.build_settings['CODE_SIGN_STYLE']        = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'macosApp/macosApp.entitlements'
  # Remove ad-hoc signing — let Xcode manage it
  config.build_settings.delete('CODE_SIGN_IDENTITY')
end

widget_target.build_configurations.each do |config|
  config.build_settings['ENABLE_APP_SANDBOX']     = 'YES'
  config.build_settings['CODE_SIGN_STYLE']        = 'Automatic'
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'SalaryWidget/SalaryWidget.entitlements'
  config.build_settings.delete('CODE_SIGN_IDENTITY')
end

project.save
puts "Done: sandbox restored, entitlements wired, automatic signing enabled"
