module Llmtest
  class PromptBuilder
    MINITEST_PROMPT = "Generate unit tests for the following Ruby on Rails model using the MiniTest Framework.\n" \
      "Only generate tests for the defined functions, not for scope, validation helpers and relations.\n" \
      "Also do not use fixtures or other setup functions, each test case has to be self contained.\n" \
      "Please mock dependencies on other Models and Classes.\n" \
      "The tests should be named in the following format: test \"test name here\"\n"

    RSPEC_PROMPT = "Generate unit tests for the following Ruby on Rails model using the RSpec Framework.\n" \
      "Only generate tests for the defined functions, not for scope, validation helpers and relations.\n" \
      "Also do not use any setup functions. All necessary setup should be done in each example (it block). So each example (it block) can be excecuted on its own.\n" \
      "Please mock dependencies on other Models and Classes.\n" \

    COVERAGE_MISSING_PROMPT = "After adding the tests that ran successfully to the test suite, there is still coverage missing."
    def initialize(rspec, file)
      @rspec = rspec
      @model_file = file
    end

    def initial_prompt(coverage = nil)
      prompt = if @rspec
        RSPEC_PROMPT
      else
        MINITEST_PROMPT
      end

      prompt += model_string(numbered_lines: false)
      prompt += coverage_missing_string(coverage) if coverage
      prompt
    end

    def coverage_missing_prompt(coverage)
      COVERAGE_MISSING_PROMPT + coverage_missing_string(coverage)
    end

    private

    def model_string(numbered_lines: false)
      # TODO add line numbers to the model string
      raise NotImplementedError if numbered_lines

      "The model source code is: \n" + @model_file.read
    end

    def coverage_missing_string(coverage)
      lines = coverage["lines"]
      uncovered_lines = lines.each_index.select { |i| lines[i] == 0 }.map { |i| i + 1 }
      branches = coverage["branches"]
      uncovered_branches = branches.select { |branch| branch["coverage"] == 0 }

      result = "Coverage missing "
      result += "for lines: #{uncovered_lines.join(",")}\n" if uncovered_lines.any?
      result += "and " if uncovered_lines.any? && uncovered_branches.any?
      result += "for branches: \n #{uncovered_branches.map { |branch| "the #{branch["type"]} branch starting on line #{branch["start_line"]}" }.join(",\n")}\n" if uncovered_branches.any?
      result
    end
  end
end
