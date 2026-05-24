require 'xcodeproj'
require 'fileutils'

FileUtils.mkdir_p('macosApp/macosApp')
FileUtils.mkdir_p('macosApp/SalaryWidget')

project_path = 'macosApp/macosApp.xcodeproj'
project = Xcodeproj::Project.new(project_path)

# Main App Target
app_target = project.new_target(:application, 'macosApp', :osx, '14.0')
app_target.product_name = 'ILoveWork'

# Widget Target
widget_target = project.new_target(:app_extension, 'SalaryWidget', :osx, '14.0')
widget_target.product_name = 'SalaryWidget'

# Main App Files
app_group = project.main_group.new_group('macosApp', 'macosApp')
app_file = app_group.new_reference('macosAppApp.swift')
app_target.source_build_phase.add_file_reference(app_file)

# Widget Files
widget_group = project.main_group.new_group('SalaryWidget', 'SalaryWidget')
widget_file = widget_group.new_reference('SalaryWidget.swift')
widget_target.source_build_phase.add_file_reference(widget_file)

# Frameworks
widget_kit = project.frameworks_group.new_reference('System/Library/Frameworks/WidgetKit.framework')
widget_kit.name = 'WidgetKit.framework'
widget_kit.source_tree = 'SDKROOT'
widget_target.frameworks_build_phase.add_file_reference(widget_kit)

swiftui_kit = project.frameworks_group.new_reference('System/Library/Frameworks/SwiftUI.framework')
swiftui_kit.name = 'SwiftUI.framework'
swiftui_kit.source_tree = 'SDKROOT'
widget_target.frameworks_build_phase.add_file_reference(swiftui_kit)
app_target.frameworks_build_phase.add_file_reference(swiftui_kit)

# Build Settings for App
app_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.suseoaa.ilovework.macos'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_NSPrincipalClass'] = 'NSApplication'
  config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
  config.build_settings['CODE_SIGN_IDENTITY'] = '-'
end

# Build Settings for Widget
widget_target.build_configurations.each do |config|
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.suseoaa.ilovework.macos.SalaryWidget'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['GENERATE_INFOPLIST_FILE'] = 'YES'
  config.build_settings['INFOPLIST_KEY_NSExtensionPointIdentifier'] = 'com.apple.widgetkit-extension'
  config.build_settings['SKIP_INSTALL'] = 'YES'
  config.build_settings['ENABLE_APP_SANDBOX'] = 'NO'
  config.build_settings['CODE_SIGN_IDENTITY'] = '-'
end

# Embed Widget in App
embed_phase = project.new(Xcodeproj::Project::Object::PBXCopyFilesBuildPhase)
embed_phase.name = 'Embed Foundation Extensions'
embed_phase.dst_subfolder_spec = '13' # PlugIns
app_target.build_phases << embed_phase

build_file = embed_phase.add_file_reference(widget_target.product_reference)
build_file.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

app_target.add_dependency(widget_target)

project.save
puts "Successfully created macosApp.xcodeproj"
