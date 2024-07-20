require "openai"

module Llmtest
  class Llm
    def initialize(model: "gpt-4o-mini", system_prompt: nil, messages: [])
      @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"], log_errors: true)
      @model = model
      @messages = messages
      @system_prompt = system_prompt
    end

    def chat(message)
      if @system_prompt && @messages.empty?
        @messages.append({role: "system", content: @system_prompt})
      end

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

    def branch
      Llm.new(model: @model, messages: @messages.clone)
    end
  end
end
