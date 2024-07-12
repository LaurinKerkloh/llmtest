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
  end
end
