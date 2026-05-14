source "https://rubygems.org"

# Ruby version compatibility
# Support Ruby 3.0+ including 3.4+ with explicit compatibility gems
ruby ">= 3.0"

gem "fastlane", "2.232.2"
gem "xcov"
gem "xcpretty"

# Ruby 3.4+ compatibility gems (removed from stdlib)
# These are required for Ruby 3.4+ but safe to include in older versions
gem "abbrev"
gem "base64"
gem "benchmark"  # Removed from stdlib in Ruby 4.0; required by mini_magick (frameit)
gem "bigdecimal"
gem "mutex_m"
gem "nkf"  # Provides kconv for CFPropertyList
gem "ostruct"

plugins_path = File.join(File.dirname(__FILE__), 'fastlane', 'Pluginfile')
eval_gemfile(plugins_path) if File.exist?(plugins_path)
