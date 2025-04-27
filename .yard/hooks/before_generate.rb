# frozen_string_literal: true

YARD::Hooks.register_hook(:before_generate) do
  # Ensure the images directory exists
  FileUtils.mkdir_p('docs/images')
  puts "✅ Created docs/images directory"
end