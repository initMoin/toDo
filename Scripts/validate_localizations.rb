#!/usr/bin/env ruby
# frozen_string_literal: true

require "json"

ROOT = File.expand_path("..", __dir__)
LANGUAGES = %w[ar es hi it ja ms th ur zh-Hans].freeze
FILES = [
  "Resources/Localizable.xcstrings",
  "Resources/InfoPlist.xcstrings"
].freeze

def value_for(entry, language)
  entry.dig("localizations", language, "stringUnit", "value")
end

def linguistic_key?(key)
  key.match?(/[A-Za-z]/)
end

failed = false

FILES.each do |relative_path|
  path = File.join(ROOT, relative_path)
  data = JSON.parse(File.read(path))
  strings = data.fetch("strings")

  puts relative_path

  LANGUAGES.each do |language|
    missing = strings.each_with_object([]) do |(key, entry), keys|
      next unless linguistic_key?(key)

      value = value_for(entry, language)
      keys << key if value.nil? || value.strip.empty?
    end

    total_linguistic_keys = strings.keys.count { |key| linguistic_key?(key) }

    if missing.empty?
      puts "  #{language}: complete"
    else
      failed = true
      puts "  #{language}: #{missing.length}/#{total_linguistic_keys} missing"
      missing.first(10).each { |key| puts "    - #{key}" }
      puts "    ... #{missing.length - 10} more" if missing.length > 10
    end
  end
end

exit(failed ? 1 : 0)
