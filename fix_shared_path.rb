require 'xcodeproj'

project_path = 'macosApp/macosApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target    = project.targets.find { |t| t.name == 'macosApp' }
widget_target = project.targets.find { |t| t.name == 'SalaryWidget' }

# Remove stale Shared group if it exists with wrong path
project.main_group.groups.each do |g|
  if g.name == 'Shared' || g.path == '../Shared' || g.path == 'Shared'
    g.remove_from_project
    break
  end
end

# Add Shared group with correct path relative to project root (macosApp/)
shared_group = project.main_group.new_group('Shared', 'Shared')
shared_group.source_tree = 'SOURCE_ROOT'

config_ref = shared_group.new_reference('Config.swift')
config_ref.source_tree = '<group>'

[app_target, widget_target].each do |target|
  # Remove stale build file entries for Config.swift
  target.source_build_phase.files.select { |bf|
    bf.file_ref&.path == 'Config.swift'
  }.each(&:remove_from_project)

  target.source_build_phase.add_file_reference(config_ref)
end

project.save
puts "Done: Shared/Config.swift correctly wired to both targets"
