#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

ROOT = File.expand_path("..", __dir__)
LANGUAGES = %w[ar es hi it ja ms th ur zh-Hans].freeze
FILES = [
  "Resources/Localizable.xcstrings",
  "Resources/InfoPlist.xcstrings"
].freeze

# Matches printf-style placeholders used by Swift localized strings:
# %@, %lld, %d, %.2f, %1$@, etc. Literal %% is ignored.
PLACEHOLDER_PATTERN = /(?<!%)%(?:\d+\$)?[-+# 0]*(?:\*|\d+)?(?:\.(?:\*|\d+))?(?:hh|h|ll|l|j|z|t|L)?[@A-Za-z]/

def placeholders(value)
  value.to_s.scan(PLACEHOLDER_PATTERN)
end

def value_for(entry, language)
  entry.dig("localizations", language, "stringUnit", "value")
end

failed = false

FILES.each do |relative_path|
  path = File.join(ROOT, relative_path)
  data = JSON.parse(File.read(path))
  strings = data.fetch("strings")

  puts relative_path

  strings.each do |key, entry|
    source_placeholders = placeholders(key)
    next if source_placeholders.empty?

    LANGUAGES.each do |language|
      localized_value = value_for(entry, language)
      next if localized_value.nil? || localized_value.strip.empty?

      localized_placeholders = placeholders(localized_value)
      next if localized_placeholders == source_placeholders

      failed = true
      puts "  #{language}: placeholder mismatch"
      puts "    key: #{key}"
      puts "    expected: #{source_placeholders.join(", ")}"
      puts "    actual:   #{localized_placeholders.join(", ")}"
      puts "    value: #{localized_value}"
    end
  end
end

if failed
  warn "Localized placeholder validation failed."
  exit 1
end

puts "Localized placeholder validation passed."
