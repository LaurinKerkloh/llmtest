require "llmtest/test_case"

module Llmtest
  class ResponseParser
    attr_reader :response, :code_blocks, :test_cases
    def initialize(response)
      @response = response
      @code_blocks = response.match(/```ruby\n(.*?)```/m).captures
      extract_test_cases
    end

    # TODO: could select specific code blocks if needed
    def extract_test_cases
      @test_cases = []
      @code_blocks.each do |code|
        Fast.search(Fast.ast(code), "(block (send nil test))").each do |test_case_node|
          test_cases << Llmtest::TestCase.new(test_case_node)
        end
      end
    end
  end
end
