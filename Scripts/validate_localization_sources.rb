#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

ROOT = File.expand_path("..", __dir__)
CATALOG = JSON.parse(File.read(File.join(ROOT, "Resources/Localizable.xcstrings"))).fetch("strings")
SOURCE_GLOBS = %w[App Core Features Services ToDo\ Mac ToDo\ Watch\ App ToDoWidget].freeze
PATTERNS = [
  /String\(localized:\s*"((?:[^"\\]|\\.)*)"/,
  /(?:Text|Label|Button|Picker|Toggle|Section|navigationTitle|accessibilityLabel|accessibilityHint)\(\s*"((?:[^"\\]|\\.)*)"/,
].freeze

missing = Hash.new { |hash, key| hash[key] = [] }

SOURCE_GLOBS.each do |directory|
  Dir.glob(File.join(ROOT, directory, "**/*.swift")).each do |path|
    source = File.read(path)
    PATTERNS.each do |pattern|
      source.scan(pattern).flatten.each do |raw_key|
        next if raw_key.empty? || raw_key.include?("\\(")

        key = raw_key.gsub('\\"', '"').gsub("\\n", "\n")
        missing[key] << path.delete_prefix("#{ROOT}/") unless CATALOG.key?(key)
      end
    end
  end
end

if missing.empty?
  puts "Localized source-key validation passed."
  exit 0
end

warn "Customer-facing source strings are missing from Localizable.xcstrings:"
missing.sort.each do |key, paths|
  warn "  - #{key.inspect} (#{paths.uniq.join(', ')})"
end
exit 1
