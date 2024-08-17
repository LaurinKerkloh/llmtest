require "openai"

module Llmtest
  # Class to chat with OpenAI's large language models. Expects the OPENAI_API_KEY environment variable to be set.
  class Llm
    # @param model [String] Model to use for the chat. For example: "gpt-4o-mini", "gpt-4o"
    # @param system_prompt [String, nil] System prompt to start the conversation with.
    # @param messages [Array<Hash>] Array of messages to continue a conversation with.
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

    # Chat with the model.
    #
    # @param message [String] Message to send to the model.
    # @return [String] Response from the model.
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
