# TODO check if test cases increase coverage
#   - check if simple_cov is set up correctly
#   - get baseline coverage before adding test cases
#   - check coverage after each test case
# TODO check if test case allready exists

require "rails/generators"
require "llmtest/llm"

module Llmtest
  module Generators
    class ModelGenerator < Rails::Generators::NamedBase
      desc "This generator creates unit tests for a given model with the help of an LLM."
      source_root File.expand_path("templates", __dir__)

      def read_test_file
        @test_file = File.join(Rails.root, "test/models", "#{file_name}_test.rb")
        # stop if the file does NOT exist
        if !File.exist?(@test_file)
          # TODO create the file if it does not exist
          puts "No test file found for #{@file_name}."
          puts "Please generate/create the test file first."
          nil
        end
        @test_file_lines = File.readlines(@test_file)
        # find and store line number after which to insert the test cases
        @line_number = @test_file_lines.find_index { |line| line.include?("class #{file_name.camelize}Test < ActiveSupport::TestCase") } + 1
      end

      def read_model_file
        model_file = File.join(Rails.root, "app/models", "#{file_name}.rb")
        @model = File.read(model_file)
      end

      def get_test_cases
        @llm = Llmtest::Llm.new
        prompt = "Generate unit tests for the following Ruby on Rails model using the MiniTest Framework:\n#{@model}"
        @response = @llm.chat(prompt)

        message = @response.dig("choices", 0, "message", "content")
        # extract the each test case from the response
        # TODO more robust regex or even a parser
        @test_cases = message.scan(/ *?test .*? do.*?end\n/ms)
      end

      def assert_tests
        # insert each test into the test file
        @test_cases.each_with_index do |test, index|
          puts "test case #{index + 1}:"
          print test
          @test_file_lines.insert(@line_number, test)
          File.open(@test_file, "w") { |file| file.puts @test_file_lines }
          status = system "rails test test/models/#{file_name}_test.rb:#{@line_number + 1}"

          if !status
            # remove the whole test case from test file because it failed
            puts "Test case failed."
            @test_file_lines.delete_at(@line_number)
            File.open(@test_file, "w") { |file| file.puts @test_file_lines }
          end

          puts "-" * 80
        end
      end

      def run_tests
        # rails_command "test test/models/#{file_name}_test.rb"
      end
    end
  end
end
