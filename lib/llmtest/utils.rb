module Llmtest
  module Utils
    def self.insert_line_numbers(string)
      string.split("\n").each_with_index.map do |line, index|
        "#{index + 1}  #{line}"
      end.join("\n")
    end

    def self.run_tests(test_file_path, test_index: nil)
      test_file_path = test_file_path.relative_path_from(Rails.root)
      if test_index
        system("rails test #{test_file_path}:#{test_index}")
      else
        system("rails test #{test_file_path}")
      end
    end

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
