require 'xcodeproj'

project_path = 'macosApp/macosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

project.targets.each do |target|
  target.build_configurations.each do |config|
    config.build_settings['ENABLE_APP_SANDBOX'] = 'YES'
  end
end

project.save
puts "Fixed sandbox settings."
