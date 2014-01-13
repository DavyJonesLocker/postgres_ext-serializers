source 'https://rubygems.org'

# Specify your gem's dependencies in postgres_ext-serializers.gemspec
gem 'postgres_ext', path: '../postgres_ext'
gemspec

unless ENV['CI'] || RUBY_PLATFORM =~ /java/
  gem 'byebug'
end
