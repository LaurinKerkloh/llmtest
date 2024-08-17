module Llmtest
  class TestCase
    # @param node [Parser::AST::Node] Node representing the test case.
    def initialize(node)
      @node = node
    end

    # Returns the source code of the test case.
    #
    # @return [String] Source code of the test case.
    def source
      @node.loc.expression.source
    end

    # Inserts the test case into a file at the specified line index.
    # Also inserts an identifier comment to be able to locate the test case, even after changes to the file.
    #
    # @param file_path [Pathname] Path to the file where the test case should be inserted.
    # @param line_index [Integer] Line index where the test case should be inserted.
    # @return [void]
    def insert_into_file(file_path, line_index)
      @test_file = file_path
      lines = file_path.readlines
      lines.insert(line_index, "#{identifier_comment}\n  #{source}")
      file_path.open("w") { |file| file.puts(lines) }
    end

    # Removes the test case from the file. Locates the test case by the identifier comment.
    #
    # @return [void]
    def remove_from_file
      test_node = Fast.search(Fast.ast(@test_file.read), "(block (send nil test))").find { |node| node.loc.line == test_index + 1 }

      lines = @test_file.readlines
      lines.slice!((test_node.loc.line - 2)..(test_node.loc.last_line - 1))
      @test_file.open("w") { |file| file.puts(lines) }
    end

    # Runs the test case.
    #
    # @return [Boolean] Whether the test case passed.
    def run
      test_line = test_index + 1
      return false if test_line.nil?
      system("rails test #{@test_file.relative_path_from(Rails.root)}:#{test_line}")
    end

    # Removes the identifier comment from the file. Used when the test case is kept.
    #
    # @return [void]
    def remove_identifier_comment
      lines = @test_file.readlines
      identifier_index = lines.index { |line| line.include?(identifier_comment) }
      return if identifier_index.nil?
      lines.delete_at(identifier_index)
      @test_file.open("w") { |file| file.puts(lines) }
    end

    private

    def test_index
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
