guard_options = {
  spring: "bundle exec ruby",
  test_folders: ['test/new_relic', 'test'], 
  all_after_pass: false
}

guard :minitest, guard_options do
  watch(%r{^lib/(.+)\.rb$})     { |m| "test/#{m[1]}_test.rb" }
  watch(%r{^test/.+_test\.rb$})
  watch(%r{^test/rum/.*})       { "test/new_relic/rack/browser_monitoring_test.rb" }
  watch('test/test_helper.rb')  { "test/new_relic" }
  watch('test/agent_helper.rb') { "test/new_relic" }
  watch('lib/new_relic/agent/configuration/default_source.rb') { "test/new_relic/agent/configuration/orphan_configuration_test.rb" }
end
