require 'xcodeproj'

project_path = 'macosApp/macosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

widget_target = project.targets.find { |t| t.name == 'SalaryWidget' }

# Add Info.plist file reference
widget_group = project.main_group.find_subpath('SalaryWidget', false)
plist_ref = widget_group.new_reference('Info.plist')

# For each build config: disable GENERATE_INFOPLIST_FILE, set INFOPLIST_FILE
widget_target.build_configurations.each do |config|
  config.build_settings.delete('INFOPLIST_KEY_NSExtensionPointIdentifier')
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'NO'
  config.build_settings['INFOPLIST_FILE'] = 'SalaryWidget/Info.plist'
end

project.save
puts "Done: Info.plist linked to SalaryWidget target"
