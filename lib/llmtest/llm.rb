require "openai"

module Llmtest
  class Llm
    def initialize
      @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"], log_errors: true)
    end

    def chat(prompt)
      response = @client.chat(
        parameters: {
          model: "gpt-3.5-turbo",
          messages: [{role: "user", content: prompt}]
        }
      )
      puts response.dig("choices", 0, "message", "content")
      response
    end
  end
end
