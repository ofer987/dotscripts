# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'new_candidate/version'

Gem::Specification.new do |spec|
  spec.name          = 'new_candidate'
  spec.version       = NewCandidate::VERSION
  spec.authors       = ['Dan Jakob Ofer']
  spec.email         = ['dan@ofer.to']

  spec.summary       = 'Create a directory for a new candidate'
  spec.description   = 'Create a directory for a new candidate'
  spec.license       = 'MIT'

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_development_dependency 'bundler', '~> 2.2.9'
  spec.add_development_dependency 'rake', '~> 10.0'

  spec.add_dependency 'mustache', '~> 1.1.1'
  spec.add_dependency 'thor', '~> 1.1.0'
end
