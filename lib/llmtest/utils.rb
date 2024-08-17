module Llmtest
  # Utility methods.
  module Utils
    # Inserts line numbers to a string.
    #
    # @param string [String] String to insert line numbers into.
    # @return [String] String with line numbers.
    def self.insert_line_numbers(string)
      string.split("\n").each_with_index.map do |line, index|
        "#{index + 1}  #{line}"
      end.join("\n")
    end

    # Run all tests or a specific test from a test file.
    #
    # @param test_file_path [Pathname] Path to the test file.
    # @param test_index [Integer, nil] Optional index of the test to run.
    #
    # @return [Boolean] Whether the test(s) passed.
    def self.run_tests(test_file_path, test_index: nil)
      test_file_path = test_file_path.relative_path_from(Rails.root)
      if test_index
        system("rails test #{test_file_path}:#{test_index}")
      else
        system("rails test #{test_file_path}")
      end
    end

    # Extract all testables from the models and write them to a CSV file.
    def self.extract_all_testables
      csv = CSV.generate do |csv|
        csv << %w[Model Method Type Callback_Type]
        Dir.glob(Rails.root.join("app", "models", "*.rb")) do |file|
          next if File.basename(file) == "application_record.rb"
          next if File.basename(file) == "current.rb"
          model_name = File.basename(file, ".rb")
          model = Llmtest::Model.new(model_name)
          model.public_method_names.each do |method|
            csv << [model_name, method, "public", nil]
          end
          model.custom_validation_method_names.each do |method|
            csv << [model_name, method, "validation", nil]
          end
          model.custom_callbacks_types_and_method_names.each do |type, method|
            csv << [model_name, method, "callback", type]
          end
        end
      end
      puts csv
      File.write(Rails.root.join("testables.csv"), csv)
    end
  end
end
