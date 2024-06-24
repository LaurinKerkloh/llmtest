class Llmtest < Thor
  desc "model NAME", "Create tests for a model"
  def model(name)
    puts "Hello #{name}"
  end
end
