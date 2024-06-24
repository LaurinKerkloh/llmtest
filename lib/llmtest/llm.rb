require "openai"

module Llmtest
  class Llm
    def initialize(model: "gpt-3.5-turbo")
      @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"], log_errors: true)
      @model = model
      @messages = []
    end

    def chat(message)
      @messages.append({role: "user", content: message})
      response = @client.chat(
        parameters: {
          model: @model,
          messages: @messages
        }
      )
      response_message = response.dig("choices", 0, "message")
      @messages.append(response_message)

      response_message["content"]
    end
  end
end
