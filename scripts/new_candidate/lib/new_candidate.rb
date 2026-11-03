# frozen_string_literal: true

require 'thor'
require 'mustache'

require_relative 'new_candidate/version'

module NewCandidate
  require_relative 'new_candidate/constants'
  require_relative 'new_candidate/notes'
  require_relative 'new_candidate/file'
  require_relative 'new_candidate/resume'
  require_relative 'new_candidate/feedback'
end
