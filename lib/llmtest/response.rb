require "fast"
require "llmtest/test_case"

module Llmtest
  class ResponseParser
    attr_reader :response, :code_block, :test_cases
    def initialize(response)
      @response = response
      @code_blocks = response.match(/```ruby\n(.*?)```/m).captures
      @test_cases = parse_test_cases
    end

    private

    # TODO: support def test_"name" syntax
    def parse_test_cases
      test_node_expression = "(block (send nil test))"
      test_cases = []
      @code_blocks.each do |code|
        Fast.search(Fast.ast(code), test_node_expression).each do |node|
          test_cases << Llmtest::TestCase.new(node)
        end
      end
    end
  end
end
