require 'xcodeproj'

project_path = 'macosApp/macosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target    = project.targets.find { |t| t.name == 'macosApp' }
widget_target = project.targets.find { |t| t.name == 'SalaryWidget' }

# ── 1. Add Shared/Config.swift to BOTH targets ──────────────────────────────

shared_group = project.main_group.find_subpath('Shared') ||
               project.main_group.new_group('Shared', '../Shared')
shared_group.set_path('../Shared')

config_ref = shared_group.files.find { |f| f.path == 'Config.swift' } ||
             shared_group.new_reference('Config.swift')

[app_target, widget_target].each do |target|
  unless target.source_build_phase.files_references.include?(config_ref)
    target.source_build_phase.add_file_reference(config_ref)
  end
end

# ── 2. Add ContentView.swift to app target ───────────────────────────────────

app_group = project.main_group.find_subpath('macosApp', false)
cv_ref = app_group.files.find { |f| f.path == 'ContentView.swift' } ||
         app_group.new_reference('ContentView.swift')

unless app_target.source_build_phase.files_references.include?(cv_ref)
  app_target.source_build_phase.add_file_reference(cv_ref)
end

# ── 3. Add WidgetKit to app target (needed for WidgetCenter.shared) ──────────

wk_already = project.frameworks_group.files.find { |f| f.name == 'WidgetKit.framework' }
unless wk_already
  wk_ref = project.frameworks_group.new_reference('System/Library/Frameworks/WidgetKit.framework')
  wk_ref.name = 'WidgetKit.framework'
  wk_ref.source_tree = 'SDKROOT'
  app_target.frameworks_build_phase.add_file_reference(wk_ref)
  puts "Added WidgetKit.framework to macosApp target"
else
  # Check if it's already in the build phase
  unless app_target.frameworks_build_phase.files_references.include?(wk_already)
    app_target.frameworks_build_phase.add_file_reference(wk_already)
    puts "Linked WidgetKit.framework in macosApp build phase"
  end
end

# ── 4. Ensure App Group entitlement on app target ────────────────────────────

app_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] ||= 'macosApp/macosApp.entitlements'
end

project.save
puts "Done: project updated successfully"
