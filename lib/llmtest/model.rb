require "llmtest/concern"

module Llmtest
  class Model
    attr_reader :file_name, :concerns

    def initialize(file_name)
      @file_name = file_name
      @concerns = initialize_concerns
    end

    def fields
      klass.columns.map { |column| "#{column.name}: #{column.type}" }
    end

    def source
      File.read(path)
    end

    def path
      Rails.root.join("app", "models", "#{file_name}.rb")
    end

    def test_file_path
      Rails.root.join("test", "models", "#{file_name}_test.rb")
    end

    def test_file_insert_line_index
      Fast.search(Fast.ast(test_file_path.read), "(class (const nil #{name}Test)").first.loc.expression.last_line - 1
    end

    def public_method_names
      private_line = Fast.search(ast, "(send nil private)").first&.loc&.line
      Fast.search(ast, "(def $_)").each_slice(2).filter_map do |node, method_symbol|
        method_symbol.to_s if private_line.nil? || node.loc.line < private_line
      end
    end

    def custom_validation_method_names
      Fast.search(ast, "(send nil validate (sym $_))").each_slice(2).map { |_, method_symbol| method_symbol.to_s }
    end

    def custom_callbacks_types_and_method_names
      Fast.capture(ast, "(send nil $_ (sym $_))").each_slice(2).filter_map { |type, method| [type.to_s, method.to_s] if type.to_s.start_with?("before", "around", "after") }
    end

    def method_lines(method_name)
      method_node = Fast.search(ast, "(def #{method_name})").first
      method_node.loc.first_line..method_node.loc.last_line
    end

    def method_source(method_name)
      method_node = Fast.search(ast, "(def #{method_name})").first
      method_node.loc.expression.source
    end

    # TODO remove
    def source_with_method_comment(method_name, comment)
      method_node = Fast.search(ast, "(def #{method_name})").first
      method_node.loc.expression.source
      with_comment = source
      with_comment.insert(method_node.loc.expression.begin_pos, "# #{comment}\n")
    end

    def associated_models
      klass.reflect_on_all_associations.map do |association|
        new(association.klass.name.underscore)
      end
    end

    private

    def initialize_concerns
      Fast.search(ast, "(send nil include $())").each_slice(2).map do |_, concern_name_node|
        # underscore turns Namespaced::ExamPle into namespaced/exam_ple
        Concern.get_or_create(concern_name_node.loc.expression.source.underscore)
      end
    end

    def ast
      Fast.ast(source)
    end

    def klass
      file_name.camelize.constantize
    end
  end
end
