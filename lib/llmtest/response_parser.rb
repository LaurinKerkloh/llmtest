require "llmtest/test_case"

module Llmtest
  # Class to parse a response from the large language model and extract test cases from it.
  class ResponseParser
    attr_reader :response

    # @param response [String] Response from the large language model.
    def initialize(response)
      @response = response
    end

    # Returns the test cases extracted from the response.
    #
    # @return [Array<Llmtest::TestCase>] Test cases extracted from the response.
    def test_cases
      test_cases = []

      code_blocks.each do |code|
        Fast.search(Fast.ast(code), "(block (send nil test))").each do |test_case_node|
          test_cases << Llmtest::TestCase.new(test_case_node)
        end
      end

      test_cases
    end

    private

    def code_blocks
      blocks = response.match(/```ruby\n(.*?)```/m)&.captures

      # assume the anwer is only code if no code block was found
      if blocks.nil?
        blocks = [@response]
      end
      blocks
    end
  end
end
