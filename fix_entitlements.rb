require 'xcodeproj'

project_path = 'macosApp/macosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.build_configurations.each do |config|
    # Remove entitlements file requirement (no provisioning profile needed)
    config.build_settings.delete('CODE_SIGN_ENTITLEMENTS')
    # Disable sandbox so both app and widget can freely read/write files
    config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
  end
end

project.save
puts "Fixed: sandbox disabled, entitlements removed"
