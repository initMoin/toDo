#!/usr/bin/env ruby
# frozen_string_literal: true

# Production code must use AppLog rather than writing directly to stdout.
# Tests, generated build products, and the separately maintained Open Source
# tree are intentionally outside this check.

ROOT = File.expand_path("..", __dir__)
SOURCE_DIRECTORIES = [
  "App",
  "Core",
  "Features",
  "Services",
  "ToDo Mac",
  "ToDo Watch App",
  "ToDoWidget"
].freeze
EXCLUDED_PATH = %r{/(?:Build|Open Source|Tests|UITests)/}
RAW_LOGGING = /\b(?:print|debugPrint|dump)\s*\(/

matches = []
SOURCE_DIRECTORIES.each do |directory|
  Dir.glob(File.join(ROOT, directory, "**/*.swift")).each do |path|
    relative_path = path.delete_prefix("#{ROOT}/")
    next if relative_path.match?(EXCLUDED_PATH)

    File.readlines(path, chomp: true).each_with_index do |line, index|
      matches << "#{relative_path}:#{index + 1}:#{line.strip}" if line.match?(RAW_LOGGING)
    end
  end
end

if matches.empty?
  puts "Raw logging validation passed."
  exit 0
end

warn "Production Swift files must not use print, debugPrint, or dump:"
matches.each { |match| warn "  #{match}" }
exit 1
