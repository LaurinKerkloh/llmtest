# can i get llm to not do setup or should i try to parse it?
#  - move necessery variable definitions from setup to the test cases
# take the whole response first and then only new test cases? -> dont like this
# prompt with only parts of the model / units? (smaller context)?
# for rspec
# could try to keep describe and context blocks

# create fixtures for each model?
# could check if simple_cov is set up correctly
# should this really be a generator, or should it be a rake task?
# rails helpers are not tested, i dont think they need to be

# move test case validation to testvalidator class
# could also leave some manual task (creating necisarry fixtures/generators)
# also accept def test_ when generating minitest tests
require "rails/generators"
require "llmtest/llm"
require "llmtest/prompt_builder"
require "parser/current"
require "fast"

module Llmtest
  module Generators
    class ModelGenerator < Rails::Generators::NamedBase
      class_option :rspec, type: :boolean, default: false, desc: "Use RSpec instead of MiniTest"

      class_option :coverage_still_missing, type: :string, default:
      "After adding the tests that ran successfully to the test suite, there is still coverage missing."

      class_option :llm_model, type: :string, default: "gpt-3.5-turbo", desc: "model to use for the llm, available models: gpt-3.5-turbo, gpt-4o"

      desc "This generator creates unit tests for a given model with the help of an LLM."
      source_root File.expand_path("templates", __dir__)

      def read_and_parse_files
        if options[:rspec]
          @test_file = Rails.root.join("spec", "models", "#{file_name}_spec.rb")
          @insert_after_node_expression = "(send (const nil RSpec) describe)"
          @test_node_expression = "(block (send nil it))"
        else
          @test_file = Rails.root.join("test", "models", "#{file_name}_test.rb")
          @insert_after_node_expression = "class (const nil #{file_name.camelize}Test)"
          @test_node_expression = "(block (send nil test))"

        end

        @model_file = Rails.root.join("app", "models", "#{file_name}.rb")
        @coverage_file = Rails.root.join("coverage", "coverage.json")
        raise "\nNo model found with the name #{@file_name}." unless @model_file.exist?
        raise "\nNo test file found for #{@file_name}.\nExpecting the file at #{@test_file}\nPlease generate/create the test file first." unless @test_file.exist?

        # find the line index to insert the test cases
        @line_index = Fast.search_file(@insert_after_node_expression, @test_file).first.loc.line
        @test_file_lines = @test_file.readlines

        @model_ast = Parser::CurrentRuby.parse_file(@model_file)
        @model = @model_file.read

        @schema_file = Rails.root.join("db", "schema.rb")
      end

      def assess_initial_coverage
        status = run_tests
        raise "\nTests failed. Please fix the failing tests first." unless status

        raise "\nCoverage file not found. Please make sure simple_cov is setup correctly." unless @coverage_file.exist?
        @coverage = JSON.parse(@coverage_file.read).dig("coverage", @model_file.to_s)

        raise "\nCoverage is already at 100%." if fully_covered?
      end

      def main_test_loop
        @llm = Llmtest::Llm.new(model: options[:llm_model])
        @prompt_builder = Llmtest::PromptBuilder.new(options[:rspec], @model_file)
        prompt = @prompt_builder.initial_prompt

        3.times do |i|
          say prompt, :yellow

          @response = @llm.chat(prompt)
          say @response, :green
          # assume the anwer is only code if not wrapped in ```ruby ```
          generated_ruby_code = if @response.match?(/```ruby\n(.*?)```/m)
            @response.match(/```ruby\n(.*?)```/m).captures.first
          else
            @response
          end
          generated_test_ast = Parser::CurrentRuby.parse(generated_ruby_code)

          @test_cases = Fast.search(generated_test_ast, @test_node_expression).map { |node| node.loc.expression.source }

          puts "]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]Round #{i + 1}[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[["
          assert_tests(@test_cases)
          break if fully_covered?
          break unless yes?("There is still some coverage missing. Do you want to continue generating tests? (y/n)")
          prompt = @prompt_builder.coverage_missing_prompt(@coverage)
        end

        puts "final coverage:"
        puts @prompt_builder.coverage_missing_string(@coverage)
      end

      private

      def run_tests(line_number = nil)
        command = if options[:rspec]
          "bundle exec rspec spec/models/#{file_name}_spec.rb"
        else
          "rails test test/models/#{file_name}_test.rb"
        end
        if line_number.present?
          command += ":#{line_number}"
        end
        system command
      end

      def assert_tests(test_cases)
        test_cases.each_with_index do |test, index|
          puts "test case #{index + 1}:"
          print test
          @test_file_lines.insert(@line_index, test)
          @test_file.open("w") { |file| file.puts @test_file_lines }
          status = run_tests(@line_index + 1)
          if !status
            puts "Test case failed."
            remove_recent_test
          else
            test_coverage = JSON.parse(@coverage_file.read).dig("coverage", @model_file.to_s)
            if !adds_coverage?(test_coverage)
              puts "Test case does not increase coverage."
              remove_recent_test
            end
          end

          puts "-" * 80
        end
      end

      def remove_recent_test
        @test_file_lines.delete_at(@line_index)
        @test_file.open("w") { |file| file.puts @test_file_lines }
      end

      def adds_coverage?(test_coverage)
        lines_newly_covered = []
        test_coverage["lines"].each_with_index do |line_coverage, index|
          if line_coverage == 1 && @coverage["lines"][index] == 0
            lines_newly_covered << index + 1
            @coverage["lines"][index] = 1
          end
        end

        branches_newly_covered = []
        test_coverage["branches"].each_with_index do |branch, index|
          if branch["coverage"] == 1 && @coverage["branches"][index]["coverage"] == 0
            branches_newly_covered << branch
            @coverage["branches"][index]["coverage"] = 1
          end
        end
        puts "lines_newly_covered: #{lines_newly_covered}"
        puts "branches_newly_covered: #{branches_newly_covered}"

        lines_newly_covered.any? || branches_newly_covered.any?
      end

      def fully_covered?
        all_lines_covered = @coverage["lines"].none? { |line| line == 0 }
        all_branches_covered = @coverage["branches"].none? { |branch| branch["coverage"] == 0 }
        all_lines_covered && all_branches_covered
      end
    end
  end
end
