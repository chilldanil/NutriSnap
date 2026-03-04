require 'xcodeproj'
project_path = '/Users/daniilchilochi/Desktop/NutriSnap/NutriSnap.xcodeproj'
project = Xcodeproj::Project.open(project_path)
main_target = project.targets.find { |t| t.name == 'NutriSnap' }
shared_target = project.targets.find { |t| t.name == 'NutriSnapShared' } || main_target

# Paths
shared_group = project.main_group.find_subpath('NutriSnapShared/Models', true)
body_group = project.main_group.find_subpath('NutriSnap/Views/Body', true)

# Files
m_file = shared_group.new_file('BodyMeasurement.swift')
b_file = body_group.new_file('BodyTrackingView.swift')
a_file = body_group.new_file('AddMeasurementSheet.swift')

# Add to targets
shared_target.add_file_references([m_file])
main_target.add_file_references([b_file, a_file, m_file])

project.save
