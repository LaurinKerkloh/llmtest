require "tty-prompt"
require "llmtest/utils"

module Llmtest
  class PromptBuilder
    MINITEST_PROMPT = "Write unit tests for the %{method_name} method of the %{model_name} Ruby on Rails model. Use the  MiniTest Framework. \n" \
                      "The %{model_name} model and the relevant related models with their database fields and source code are listed below:\n"

    MODEL_CONTEXT = "%{model_name}: %{model_fields}\n" \
      "%{model_path}\n" \
      "```ruby\n" \
      "%{model_source}\n" \
      "```\n"

    CONCERN_CONTEXT = "The included {concern_name} concern:\n" \
                      "%{concern_path}\n" \
                      "```ruby\n" \
                      "%{concern_source}\n" \
                      "```\n"

    # insert before the method that is supposed to be tested
    METHOD_COMMENT = "unit test for this method"

    def self.model_prompt(model, with_line_numbers: false)
      model_source = if with_line_numbers
        Llmtest::Utils.insert_line_numbers(model.source)
      else
        model.source
      end
      MODEL_CONTEXT % {model_name: model.name, model_fields: model.fields.join(", "), model_path: model.path, model_source: model_source}
    end

    def initialize(model)
      @model = model
    end

    def select_method
      @method_name = TTY::Prompt.new.select("Select the method you want to create tests for.", @model.method_names)
      @model.insert_comment_before_method(@method_name, METHOD_COMMENT)
      @method_name
    end

    def select_related_models
      related_model_names = TTY::Prompt.new.multi_select("Select which related models to include in the prompt", @model.get_association_model_names)
      @related_models = related_model_names.map { |model_name| Model.new(model_name) }
    end

    def prompt(after_instruction = nil, with_line_numbers: true)
      prompt = (MINITEST_PROMPT % {method_name: @method_name, model_name: @model.name})
      prompt += "#{after_instruction}\n" if after_instruction
      prompt += self.class.model_prompt(@model, with_line_numbers: with_line_numbers)
      prompt += @related_models.map { |model| self.class.model_prompt(model) }.join
      prompt += Concern.concerns.map { |concern| CONCERN_CONTEXT % {concern_name: concern.name, concern_path: concern.path, concern_source: concern.source} }.join
      prompt
    end

    private

    def coverage_missing_string(coverage)
      lines = coverage["lines"]
      uncovered_lines = lines.each_index.select { |i| lines[i] == 0 }.map { |i| i + 1 }
      branches = coverage["branches"]
      uncovered_branches = branches.select { |branch| branch["coverage"] == 0 }

      result = "Coverage missing "
      result += "for lines: #{uncovered_lines.join(",")}\n" if uncovered_lines.any?
      result += "and " if uncovered_lines.any? && uncovered_branches.any?
      result += "for branches: \n #{uncovered_branches.map { |branch| "the #{branch["type"]} branch starting on line #{branch["start_line"]}" }.join(",\n")}\n" if uncovered_branches.any?
      result
    end
  end
end
