require "rails/generators"

module Llmtest
  module Generators
  class LlmtestGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def copy_file
      copy_file "llmtest.rb", "#{Rails.root}/config/llmtest.rb"
    end
  end
end
