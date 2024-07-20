require "llmtest/test_case"

module Llmtest
  class ResponseParser
    attr_reader :response, :code_blocks, :test_cases
    def initialize(response)
      @response = response
      @code_blocks = response.match(/```ruby\n(.*?)```/m)&.captures
      extract_test_cases
    end

    def extract_test_cases
      @test_cases = []

      # assume the anwer is only code if no code block was found
      if @code_blocks.nil?
        @code_blocks = [@response]
      end

      @code_blocks.each do |code|
        Fast.search(Fast.ast(code), "(block (send nil test))").each do |test_case_node|
          @test_cases << Llmtest::TestCase.new(test_case_node)
        end
      end

      @test_cases
    end
  end
end
