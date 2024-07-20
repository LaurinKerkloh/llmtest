require "tty-prompt"
require "llmtest/utils"

module Llmtest
  class PromptBuilder
    SYSTEM_PROMPT = "You write tests for Ruby on Rails models using the MiniTest framework. \n" \
                    "You will be prompted to write tests for either a public method, a custom validation or a custom callback.\n" \
                    "The model and the relevant related models with their database fields and source code will be provided to you.\n" \
                    "Aswell as the source code of any included concerns.\n" \
                    "There are fixtures available for each model, called one and two, make use of them and modify the necesarry fields in each test case.\n"
    # "When testing callbacks or validations do not test the called methods themselves, but the behavior of the model when the callback or validation is triggered.\n"

    COVERAGE_PROMPT = "After including some or all of the tests, there is coverage missing. \n" \
                      "Uncovered lines: %{uncovered_lines}\n" \
                      "Uncovered branches: %{uncovered_branches}\n"

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

    # inserted before the method that is supposed to be tested
    METHOD_COMMENT = "unit test this method"

    def self.model_prompt(model, with_line_numbers: false, comment_method: nil, comment: METHOD_COMMENT)
      source = if comment_method
        model.source_with_method_comment(comment_method, comment)
      else
        model.source
      end

      if with_line_numbers
        source = Llmtest::Utils.insert_line_numbers(source)
      end

      MODEL_CONTEXT % {model_name: model.name, model_fields: model.fields.join(", "), model_path: model.path, model_source: source}
    end

    def initialize(model)
      @model = model
    end

    def select_testable
      public_methods = @model.public_method_names.to_h { |method_name| ["(public method) #{method_name}", ["public_method", method_name]] }
      custom_validations = @model.custom_validation_method_names.to_h { |method_name| ["(custom validation) #{method_name}", ["custom_validation", method_name]] }
      custom_callbacks = @model.custom_callbacks_types_and_method_names.to_h { |type, method_name| ["(custom #{type} callback) #{method_name}", [["custom_callback", type], method_name]] }
      choices = public_methods.merge(custom_validations).merge(custom_callbacks)
      puts choices
      @testable_type, @method_name = TTY::Prompt.new.select("Select what you want to create tests for.", choices)

      [@testable_type, @method_name]
    end

    def select_related_models
      related_model_names = TTY::Prompt.new.multi_select("Select which related models to include in the prompt", @model.get_association_model_names)
      @related_models = related_model_names.map { |model_name| Model.new(model_name) }
    end

    def prompt(after_instruction = nil, with_line_numbers: true)
      prompt = (BASE_PROMPT % {testable_type: @testable_type, method_name: @method_name, model_name: @model.name})
      prompt += "#{after_instruction}\n" if after_instruction
      prompt += self.class.model_prompt(@model, with_line_numbers: with_line_numbers)
      prompt += @related_models.map { |model| self.class.model_prompt(model) }.join
      prompt += Concern.concerns.map { |concern| CONCERN_CONTEXT % {concern_name: concern.name, concern_path: concern.path, concern_source: concern.source} }.join
      prompt
    end

    def coverage_prompt(coverage_tracker)
      uncovered_lines = coverage_tracker.uncovered_lines(in_original_file: true)
      uncovered_branches = coverage_tracker.uncovered_branches(in_original_file: true)
      COVERAGE_PROMPT % {uncovered_lines: uncovered_lines, uncovered_branches: uncovered_branches}
    end
  end
end
