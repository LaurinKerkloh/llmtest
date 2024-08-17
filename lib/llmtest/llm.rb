require "openai"

module Llmtest
  class Llm
    def initialize(model, system_prompt: nil, messages: [])
      @client = OpenAI::Client.new(access_token: ENV["OPENAI_API_KEY"], log_errors: true)

      available_models = @client.models.list["data"].map { |model| model["id"] }
      unless available_models.include?(model)
        raise ArgumentError, "Invalid Model '#{model}'. Available models: #{available_models.join(", ")}"
      end

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
  end
end
