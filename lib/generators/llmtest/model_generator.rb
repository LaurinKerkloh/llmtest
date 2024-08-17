# let it create fixtures?

require "rails/generators"
require "llmtest/llm"
require "llmtest/model"
require "llmtest/prompt_builder"
require "llmtest/coverage_tracker"
require "tty-prompt"
require "llmtest/response_parser"
require "fast"

module Llmtest
  module Generators
    class ModelGenerator < Rails::Generators::NamedBase
      class_option :llm_model, type: :string, default: "gpt-4o-mini", desc: "model to use for the llm, available models: gpt-4o-mini, gpt-4o"

      desc "This generator helps creating unit tests for a given model using a Large Language Model."

      source_root File.expand_path("templates", __dir__)

      DEVIDER = "--------------------------------------------------------------------------------"
      def main
        console = TTY::Prompt.new
        model = Llmtest::Model.new(file_name)
        llm = Llmtest::Llm.new(options[:llm_model], system_prompt: Llmtest::PromptBuilder::SYSTEM_PROMPT)
        prompt_builder = Llmtest::PromptBuilder.new(model)

        coverage_path = Rails.root.join("coverage", "coverage.json")
        console.say("Please make sure the test file at #{model.test_file_path} exists and that it contains a test class.\nAlso make sure that simple_cov is set up to write coverage to #{coverage_path}.")
        console.keypress("Press space or enter when you are sure that everything is setup.", keys: [:space, :return])

        # Select method to test
        testable_type, selected_method = prompt_builder.select_testable
        console.say("Selected #{testable_type}:\n#{model.method_source(selected_method)}")

        # initialize coverage tracker
        coverage_tracker = Llmtest::CoverageTracker.new(
          coverage_path,
          model.path,
          model.method_lines(selected_method)
        )

        # run tests to get initial coverage
        success = Llmtest::Utils.run_tests(model.test_file_path)
        until success
          console.say("Tests failed. Please fix the failing tests first.")
          console.keypress("Press space or enter to try again.", keys: [:space, :return])
          success = Llmtest::Utils.run_tests(model.test_file_path)
        end

        coverage_tracker.record_coverage

        # print initial coverage of selected method
        console.say(coverage_tracker.to_s)

        # select related models to include in the prompt
        prompt_builder.select_related_models
        prompt = prompt_builder.prompt

        # print prompt and give chance to add to it
        console.say(prompt)
        if console.yes?("Do you want to add to this prompt?", default: false)
          input = console.ask("Enter what you want to add. (Will be inserted before the model description.)")
          prompt = prompt_builder.prompt(input)
        end

        # get response from llm
        response = llm.chat(prompt)

        # main loop (missing coverage)
        loop do
          # loop to allow for additional prompts

          loop do
            console.say("Response:")
            console.say(response)

            selection = console.select("Do you want to continue with this response or specify with an additional prompt?", %w[continue specify])

            break if selection == "continue"

            input = console.ask("Enter your prompt.")
            response = llm.chat(input)
          end

          # extract test cases from response
          response_parser = Llmtest::ResponseParser.new(response)
          test_cases = response_parser.test_cases
          console.say("Found #{test_cases.count} test cases.")

          test_cases.each_with_index do |test_case, index|
            # introduce test case
            console.say("Test case number #{index + 1}:")
            console.say(test_case.source)

            insert = console.yes?("Do you want to insert this test case or skip it? (You may edit the test suite afterwards and before the test is run.)", default: true)
            next if !insert

            test_case.insert_into_file(model.test_file_path, model.test_file_insert_line_index)

            loop do
              console.keypress("Press space or enter when you are ready to run the test case", keys: [:space, :return])
              status = test_case.run

              if status
                console.say("Test case passed.")

                covered_lines, covered_branches = coverage_tracker.newly_covered
                console.say("Newly covered: #{covered_lines}")
                console.say("Newly covered branches: #{covered_branches}")

                if console.yes?("Do you want to keep this test case?")
                  test_case.remove_identifier_comment
                else
                  test_case.remove_from_file
                end

                break
              else
                console.say("Test case failed.")
                # TODO llm based repair
                # record error
                # read test (-file?)
                # branch llm chat
                # prompt for repair
                # parse new test
                select = console.select("Do you want to edit the test or discard it?", %w[edit discard])
                case select
                when "edit"
                  next
                when "discard"
                  test_case.remove_from_file
                  break
                end
              end
            end
          end

          # exit if fully covered
          if coverage_tracker.fully_covered?
            console.say("Method under test is fully covered. Exiting.")
            break
          end

          console.say("#{Llmtest::Utils.insert_line_numbers(model.method_source(selected_method))}\n\n" \
                      "uncovered lines: #{coverage_tracker.uncovered_lines}\n" \
                      "undercovered branches: #{coverage_tracker.uncovered_branches}")

          break if !console.yes?("Do you want to ask for additional test cases covering uncovered lines?")

          # prompt for additional test cases
          prompt = prompt_builder.coverage_prompt(coverage_tracker)
          console.say("Prompt:\n#{prompt}")
          response = llm.chat(prompt)
        end
      end
    end
  end
end
