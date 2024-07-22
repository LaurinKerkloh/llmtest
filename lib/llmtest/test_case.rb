module Llmtest
  class TestCase
    attr_reader :source

    def initialize(node)
      @source = node.loc.expression.source
      # @name = Fast.match?(node, "(send nil test (str $_))").first
    end

    def insert_into_file(file_path, line_index)
      @test_file = file_path
      lines = file_path.readlines
      lines.insert(line_index, "#{identifier_comment}\n  #{@source}")
      file_path.open("w") { |file| file.puts(lines) }
    end

    def remove_from_file
      test_node = Fast.search(Fast.ast(@test_file.read), "(block (send nil test))").find { |node| node.loc.line == get_test_index + 1 }

      lines = @test_file.readlines
      lines.slice!((test_node.loc.line - 2)..(test_node.loc.last_line - 1))
      @test_file.open("w") { |file| file.puts(lines) }
    end

    def run
      test_line = get_test_index + 1
      return false if test_line.nil?
      system("rails test #{@test_file.relative_path_from(Rails.root)}:#{test_line}")
    end

    def remove_identifier_comment
      lines = @test_file.readlines
      identifier_index = lines.index { |line| line.include?(identifier_comment) }
      return if identifier_index.nil?
      lines.delete_at(identifier_index)
      @test_file.open("w") { |file| file.puts(lines) }
    end

    private

    def get_test_index
      lines = @test_file.readlines
      identifier_index = lines.index { |line| line.include?(identifier_comment) }
      return nil if identifier_index.nil?
      identifier_index + 1
    end

    def identifier_comment
      "# Llmtest Identifier: #{object_id}"
    end
  end
end
