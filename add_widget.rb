require 'xcodeproj'

project_path = 'iosApp/iosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

if project.targets.find { |t| t.name == 'SalaryWidgetExtension' }
  puts "Target already exists."
  exit 0
end

app_target = project.targets.find { |t| t.name == 'iosApp' }

widget_target = project.new_target(:app_extension, 'SalaryWidgetExtension', :ios, '16.0')
widget_target.product_name = 'SalaryWidgetExtension'

group = project.main_group.find_subpath('SalaryWidget', true)
group.set_source_tree('<group>')
group.set_path('../SalaryWidget')
file_ref = group.new_reference('SalaryWidget.swift')

widget_target.source_build_phase.add_file_reference(file_ref)

framework_ref = project.frameworks_group.new_reference('System/Library/Frameworks/WidgetKit.framework')
framework_ref.name = 'WidgetKit.framework'
framework_ref.source_tree = 'SDKROOT'
widget_target.frameworks_build_phase.add_file_reference(framework_ref)

swiftui_ref = project.frameworks_group.new_reference('System/Library/Frameworks/SwiftUI.framework')
swiftui_ref.name = 'SwiftUI.framework'
swiftui_ref.source_tree = 'SDKROOT'
widget_target.frameworks_build_phase.add_file_reference(swiftui_ref)

widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.suseoaa.ilovework.SalaryWidgetExtension'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_NSExtensionPointIdentifier'] = 'com.apple.widgetkit-extension'
  config.build_settings['INFOPLIST_KEY_CFBundleDisplayName'] = 'Salary Widget'
  config.build_settings['CURRENT_PROJECT_VERSION'] = '1'
  config.build_settings['MARKETING_VERSION'] = '1.0'
  config.build_settings['SKIP_INSTALL'] = 'YES'
end

embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed_phase.name = 'Embed Foundation Extensions'
embed_phase.dst_subfolder_spec = '13' # PlugIns
app_target.build_phases << embed_phase

build_file = embed_phase.add_file_reference(widget_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

app_target.add_dependency(widget_target)

project.save
puts "Successfully added SalaryWidgetExtension to iosApp.xcodeproj"
