require "llmtest/concern"

module Llmtest
  # Class to represent a model in the Rails application.
  class Model
    attr_reader :file_name

    # @param file_name [String] Name of the model file. Example: "article" or "line_item"
    def initialize(file_name)
      @file_name = file_name
    end

    # Returns the database models fields and their types.
    #
    # @return [Array<String>] Array of strings with the format "field_name: field_type"
    def fields
      klass.columns.map { |column| "#{column.name}: #{column.type}" }
    end

    # Returns the source code of the model file.
    #
    # @return [String] Source code of the model file.
    def source
      File.read(path)
    end

    # Returns the path to the model file.
    #
    # @return [Pathname] Path to the model file.
    def path
      Rails.root.join("app", "models", "#{file_name}.rb")
    end

    # Returns the path to the test file for the model.
    # The test file is expected to be in the test/models directory.
    #
    # @return [Pathname] Path to the test file for the model.
    def test_file_path
      Rails.root.join("test", "models", "#{file_name}_test.rb")
    end

    # Returns the line index where to insert a new test method in the test file.
    #
    # @return [Integer] Line index where to insert a new test method in the test file.
    def test_file_insert_line_index
      Fast.search(Fast.ast(test_file_path.read), "(class (const nil #{name}Test)").first.loc.expression.last_line - 1
    end

    # Returns the names of the public methods in the model.
    #
    # @return [Array<String>] Names of the public methods in the model.
    def public_method_names
      private_line = Fast.search(ast, "(send nil private)").first&.loc&.line
      Fast.search(ast, "(def $_)").each_slice(2).filter_map do |node, method_symbol|
        method_symbol.to_s if private_line.nil? || node.loc.line < private_line
      end
    end

    # Returns the method names of the custom validation methods in the model.
    #
    # @return [Array<String>] Names of the custom validation methods in the model.
    def custom_validation_method_names
      Fast.search(ast, "(send nil validate (sym $_))").each_slice(2).map { |_, method_symbol| method_symbol.to_s }
    end

    # Returns the mehtod names of the custom callbacks in the model.
    #
    # @return [Array<Array<String>>] Array of arrays with the type of the callback and the method name.
    def custom_callbacks_types_and_method_names
      Fast.capture(ast, "(send nil $_ (sym $_))").each_slice(2).filter_map { |type, method| [type.to_s, method.to_s] if type.to_s.start_with?("before", "around", "after") }
    end

    # Returns the lines of a method in the model.
    #
    # @param method_name [String] Name of the method.
    # @return [Range] Range of lines of the method.
    def method_lines(method_name)
      method_node = Fast.search(ast, "(def #{method_name})").first
      method_node.loc.first_line..method_node.loc.last_line
    end

    # Returns the source code of a method in the model.
    #
    # @param method_name [String] Name of the method.
    # @return [String] Source code of the method.
    def method_source(method_name)
      method_node = Fast.search(ast, "(def #{method_name})").first
      method_node.loc.expression.source
    end

    # Returns the all associated models of the model.
    #
    # @return [Array<Llmtest::Model>] Associated models of the model.
    def associated_models
      models = []
      klass.reflect_on_all_associations.map do |association|
        models << self.class.new(association.klass.name.underscore)
      end
      models
    end

    # Returns the name of the model class.
    # Example: "Article" or "LineItem"
    #
    # @return [String] Name of the model class.
    def name
      file_name.camelize
    end

    # Returns any included Concerns.
    #
    # @return [Array<Llmtest::Concern>] Included Concerns.
    def concerns
      Fast.search(ast, "(send nil include $())").each_slice(2).map do |_, concern_name_node|
        # underscore turns Namespaced::ExamPle into namespaced/exam_ple
        Concern.get_or_create(concern_name_node.loc.expression.source.underscore)
      end
    end

    private

    def ast
      Fast.ast(source)
    end

    def klass
      name.constantize
    end
  end
end
