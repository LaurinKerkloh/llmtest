# Llmtest

This gem provides a Ruby on Rails generator, which uses OpenAI's large language model to generate tests for your Rails models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'llmtest', git: 'https://github.com/LaurinKerkloh/llmtest'
```

## Setup

To use the generator, you need to expose your OpenAI API key in the OPENAI_API_KEY environment variable.

```bash
export OPENAI_API_KEY=your-api-key
```

Also the coverage tracker SimpleCov needs to be setup to write the coverage report to the file `coverage/coverage.json`.
And branch coverage needs to be enabled.

To do this, add the following to your `test/test_helper.rb`:

```ruby
require "simplecov"
require "simplecov_json_formatter"
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter, # optional: to also get the HTML report
  SimpleCov::Formatter::JSONFormatter
])

SimpleCov.start do
  enable_coverage :branch
end
```

## Usage

Before tests can be generated, two fixtures need to be created for each model and its associations, that tests should be generated for.
These fixtures do not need any specific content, but should be valid instances of the model.

After fixtures are created, the test generation process can be started by running the following command:

```bash
rails generate llmtest:model_tests model_name
```

By default, the generator will use OpenAI's GPT-4o-mini model but with the `--llm_model` option, a different model can be specified.
Refer to the OpenAI API documentation for a list of available models.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
