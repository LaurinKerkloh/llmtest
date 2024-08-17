require "tty-prompt"
require "llmtest/utils"

module Llmtest
  # Class to build prompts for the user to write tests for a model.
  class PromptBuilder
    SYSTEM_PROMPT = "You write tests for Ruby on Rails models using the MiniTest framework. \n" \
                    "You will be prompted to write tests for either a public method, a custom validation or a custom callback.\n" \
                    "The model and the relevant related models with their database fields and source code will be provided to you.\n" \
                    "Aswell as the source code of any included concerns.\n" \
                    "There are two default fixtures available for each model, called one and two, make use of them and modify fields as needed for each test.\n"

    COVERAGE_PROMPT = "After including some or all of the tests, there is coverage missing. \n" \
                      "Uncovered lines: %{uncovered_lines}\n" \
                      "Uncovered branches: %{uncovered_branches}\n" \
                      "Only give the new tests that cover the missing lines and branches."

    BASE_PROMPT = "Test the %{testable_type} '%{method_name}' of the %{model_name} model.\n" \
                      "Relevant model information:\n"

    MODEL_CONTEXT = "%{model_name}: %{model_fields}\n" \
      "%{model_path}\n" \
      "```ruby\n" \
      "%{model_source}\n" \
      "```\n"

    CONCERN_CONTEXT = "The included %{concern_name} concern:\n" \
                      "%{concern_path}\n" \
                      "```ruby\n" \
                      "%{concern_source}\n" \
                      "```\n"

    # Returns a prompt with information and source code of a given model. Optionally with line numbers added to each line.
    #
    # @param model [Llmtest::Model]
    # @param with_line_numbers [Boolean]
    # @return [String]
    def self.model_prompt(model, with_line_numbers: false)
      source = model.source

      if with_line_numbers
        source = Llmtest::Utils.insert_line_numbers(source)
      end

      MODEL_CONTEXT % {model_name: model.name, model_fields: model.fields.join(", "), model_path: model.path, model_source: source}
    end

    # @param [Llmtest::Model] model
    def initialize(model)
      @model = model
    end

    # Select a testable (public method, custom validation or custom callback) from the model using the CLI.
    #
    # @return [Array<String>] The type of the testable method and the method name.
    def select_testable
      public_methods = @model.public_method_names.to_h { |method_name| ["(public method) #{method_name}", ["public_method", method_name]] }
      custom_validations = @model.custom_validation_method_names.to_h { |method_name| ["(custom validation) #{method_name}", ["custom_validation", method_name]] }
      custom_callbacks = @model.custom_callbacks_types_and_method_names.to_h { |type, method_name| ["(custom #{type} callback) #{method_name}", [["custom_callback", type], method_name]] }
      choices = public_methods.merge(custom_validations).merge(custom_callbacks)
      @testable_type, @method_name = TTY::Prompt.new.select("Select what you want to create tests for.", choices)

      [@testable_type, @method_name]
    end

    # Select related models to include in the prompt using the CLI.
    #
    # @return [Array<Llmtest::Model>] The selected related models.
    def select_related_models
      associated_models = @model.associated_models
      if associated_models.empty?
        @related_models = []
        return @related_models
      end
      choices = associated_models.map { |model| {name: model.name, value: model} }
      @related_models = TTY::Prompt.new.multi_select("Select which related models to include in the prompt", choices)
    end

    # Constructs prompt to write tests for the selected testable and includes the model and related models.
    # It is required to call select_testable and select_related_models before calling this method.
    #
    # @param after_instruction [String] additional instruction to include in the prompt.
    # @param with_line_numbers [Boolean] whether to include line numbers in the source code of the model under test.
    # @return [String] The constructed prompt.
    def prompt(after_instruction = nil, with_line_numbers: true)
      prompt = (BASE_PROMPT % {testable_type: @testable_type, method_name: @method_name, model_name: @model.file_name})
      prompt += "#{after_instruction}\n" if after_instruction
      prompt += self.class.model_prompt(@model, with_line_numbers: with_line_numbers)
      prompt += @related_models.map { |model| self.class.model_prompt(model) }.join
      prompt += Concern.from_models([@model, @related_models].flatten).map do |concern|
        CONCERN_CONTEXT % {concern_name: concern.name, concern_path: concern.path, concern_source: concern.source}
      end.join

      prompt
    end

    # Constructs missing coverage prompt based on the given coverage tracker.
    #
    # @param coverage_tracker [Llmtest::CoverageTracker]
    # @return [String] The constructed prompt.
    def coverage_prompt(coverage_tracker)
      uncovered_lines = coverage_tracker.uncovered_lines(in_original_file: true)
      uncovered_branches = coverage_tracker.uncovered_branches(in_original_file: true)
      COVERAGE_PROMPT % {uncovered_lines: uncovered_lines, uncovered_branches: uncovered_branches}
    end
  end
end
