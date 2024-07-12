# also accept def test_ when generating minitest tests

# let it create fixtures?

require "rails/generators"
require "llmtest/llm"
require "llmtest/model"
require "llmtest/prompt_builder"
require "llmtest/coverage_tracker"
require "tty-prompt"
require "llmtest/response_parser"
require "parser/current"
require "fast"

module Llmtest
  module Generators
    class ModelGenerator < Rails::Generators::NamedBase
      class_option :llm_model, type: :string, default: "gpt-3.5-turbo", desc: "model to use for the llm, available models: gpt-3.5-turbo, gpt-4o"

      desc "This generator helps creating unit tests for a given model using a Large Language Model."

      source_root File.expand_path("templates", __dir__)

      def one
        console = TTY::Prompt.new
        model = Llmtest::Model.new(file_name)
        llm = Llmtest::Llm.new(model: options[:llm_model])
        prompt_builder = Llmtest::PromptBuilder.new(model)
        coverage_path = Rails.root.join("coverage", "coverage.json")
        console.say("Please make sure the test file at #{model.test_file_path} exists and that it contains a test class.\nAlso make sure  that simple_cov is set up to write coverage to #{coverage_path}.")
        console.keypress("Press space or enter when you are sure that everything is setup.", keys: [:space, :return])

        # Select method
        selected_method = prompt_builder.select_method
        console.say("Selected method:\n#{model.method_source(selected_method)}")

        coverage_tracker = Llmtest::CoverageTracker.new(
          coverage_path,
          model.path,
          model.method_lines(selected_method)
        )

        success = Llmtest::Utils.run_tests(model.test_file_path)
        until success
          console.say("Tests failed. Please fix the failing tests first.")
          console.keypress("Press space or enter to try again.", keys: [:space, :return])
          success = Llmtest::Utils.run_tests(model.test_file_path)
        end

        coverage_tracker.record_initial_coverage

        console.say(coverage_tracker.to_s)

        # select related models to include in the prompt
        prompt_builder.select_related_models
        prompt = prompt_builder.prompt
        console.say(prompt)

        if console.yes?("Do you want to add to this prompt?", default: false)
          input = console.ask("Enter what you want to add. (Will be inserted before the model description.)")
          prompt = prompt_builder.prompt(input)
        end

        response_parser = Llmtest::ResponseParser.new(llm.chat(prompt))
        console.say("Response:")
        console.say(response_parser.response)

        # TODO: additional prompt chance

        test_cases = response_parser.test_cases
        console.say("Found #{test_cases.count} test cases.")
        test_cases.each_with_index do |test_case, index|
          console.say("Test case number #{index + 1}:")
          console.say(test_case.source)
          if console.yes?("Do you want to insert this test case or skip it?\nYou may edit the test suite before the test is run.")
            test_case.insert_into_file(model.test_file_path, model.test_file_insert_line_index)
            loop do
              console.keypress("Press space or enter when you are ready to run the test case", keys: [:space, :return])
              status = test_case.run
              if status
                console.say("Test case passed.")
                # TODO: coverage
                covered_lines, covered_branches = coverage_tracker.newly_covered
                console.say("Newly covered: #{covered_lines}")
                console.say("Newly covered branches: #{covered_branches}")
                if console.yes?("Do you want to keep this test case?")
                  test_case.remove_identifier_comment
                  break
                end
              else
                console.say("Test case failed.")
                if console.yes?("Do you want to try again?")
                  next
                elsif console.yes?("Do you want to discard this test case?")
                  test_case.remove_from_file
                  break
                end
              end
            end
          end
        end
      end
    end
  end
end

#         @test_file = Rails.root.join("test", "models", "#{file_name}_test.rb")
#         @insert_after_node_expression = "class (const nil #{file_name.camelize}Test)"
#         @test_node_expression = "(block (send nil test))"
#
#         @coverage_file = Rails.root.join("coverage", "coverage.json")
#         raise "\nNo model found with the name #{@file_name}." unless @model_file.exist?
#         raise "\nNo test file found for #{@file_name}.\nExpecting the file at #{@test_file}\nPlease generate/create the test file first." unless @test_file.exist?
#
#         # find the line index to insert the test cases
#         @line_index = Fast.search_file(@insert_after_node_expression, @test_file).first.loc.line
#         @test_file_lines = @test_file.readlines
#
#         @model_ast = Parser::CurrentRuby.parse_file(@model_file)
#         @model = @model_file.read
#
#         @schema_file = Rails.root.join("db", "schema.rb")
#       end
#
#       def assess_initial_coverage
#         status = run_tests
#         raise "\nT)ests failed. Please fix the failing tests first." unless status
#
#         raise "\nCoverage file not found. Please make sure simple_cov is setup correctly." unless @coverage_file.exist?
#         @coverage = JSON.parse(@coverage_file.read).dig("coverage", @model_file.to_s)
#
#         raise "\nCoverage is already at 100%." if fully_covered?
#       end
#
#       def main_test_loop
#         @llm = Llmtest::Llm.new(model: options[:llm_model])
#         @prompt_builder = Llmtest::PromptBuilder.new(options[:rspec], @model_file)
#         prompt = @prompt_builder.initial_prompt
#
#         3.times do |i|
#           say prompt, :yellow
#
#           @response = @llm.chat(prompt)
#           say @response, :green
#           # assume the anwer is only code if not wrapped in ```ruby ```
#           generated_ruby_code = if @response.match?(/```ruby\n(.*?)```/m)
#             @response.match(/```ruby\n(.*?)```/m).captures.first
#           else
#             @response
#           end
#           generated_test_ast = Parser::CurrentRuby.parse(generated_ruby_code)
#
#           @test_cases = Fast.search(generated_test_ast, @test_node_expression).map { |node| node.loc.expression.source }
#
#           puts "]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]Round #{i + 1}[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[[["
#           assert_tests(@test_cases)
#           break if fully_covered?
#           break unless yes?("There is still some coverage missing. Do you want to continue generating tests? (y/n)")
#           prompt = @prompt_builder.coverage_missing_prompt(@coverage)
#         end
#
#         puts "final coverage:"
#         puts @prompt_builder.coverage_missing_string(@coverage)
#       end
#
#       private
#
#       def run_tests(line_number = nil)
#         command = if options[:rspec]
#           "bundle exec rspec spec/models/#{file_name}_spec.rb"
#         else
#           "rails test test/models/#{file_name}_test.rb"
#         end
#         if line_number.present?
#           command += ":#{line_number}"
#         end
#         system command
#       end
#
#       def assert_tests(test_cases)
#         test_cases.each_with_index do |test, index|
#           puts "test case #{index + 1}:"
#           print test
#           @test_file_lines.insert(@line_index, test)
#           @test_file.open("w") { |file| file.puts @test_file_lines }
#           status = run_tests(@line_index + 1)
#           if !status
#             puts "Test case failed."
#             remove_recent_test
#           else
#             test_coverage = JSON.parse(@coverage_file.read).dig("coverage", @model_file.to_s)
#             if !adds_coverage?(test_coverage)
#               puts "Test case does not increase coverage."
#               remove_recent_test
#             end
#           end
#
#           puts "-" * 80
#         end
#       end
#
#       def remove_recent_test
#         @test_file_lines.delete_at(@line_index)
#         @test_file.open("w") { |file| file.puts @test_file_lines }
#       end
#
#       def adds_coverage?(test_coverage)
#         lines_newly_covered = []
#         test_coverage["lines"].each_with_index do |line_coverage, index|
#           if line_coverage == 1 && @coverage["lines"][index] == 0
#             lines_newly_covered << index + 1
#             @coverage["lines"][index] = 1
#           end
#         end
#
#         branches_newly_covered = []
#         test_coverage["branches"].each_with_index do |branch, index|
#           if branch["coverage"] == 1 && @coverage["branches"][index]["coverage"] == 0
#             branches_newly_covered << branch
#             @coverage["branches"][index]["coverage"] = 1
#           end
#         end
#         puts "lines_newly_covered: #{lines_newly_covered}"
#         puts "branches_newly_covered: #{branches_newly_covered}"
#
#         lines_newly_covered.any? || branches_newly_covered.any?
#       end
#
#       def fully_covered?
#         all_lines_covered = @coverage["lines"].none? { |line| line == 0 }
#         all_branches_covered = @coverage["branches"].none? { |branch| branch["coverage"] == 0 }
#         all_lines_covered && all_branches_covered
#       end
#     end
#   end
# end
