require "llmtest/concern"

module Llmtest
  class Model
    attr_reader :file_name, :name, :path, :klass, :fields, :source

    def initialize(file_name)
      @file_name = file_name
      @name = file_name.camelize
      @path = Rails.root.join("app", "models", "#{file_name}.rb")
      @klass = @name.constantize
      @fields = @klass.columns.map { |column| "#{column.name}: #{column.type}" }
      @source = File.read(@path)
      @concerns = get_concerns
    end

    def test_file_path
      Rails.root.join("test", "models", "#{file_name}_test.rb")
    end

    def test_file_insert_line_index
      Fast.search_file("(class (const nil #{name}Test)", test_file_path).first.loc.expression.last_line - 1
    end

    def method_names
      Fast.search(Fast.ast(@source), "(def $_)").each_slice(2).map { |_, method_symbol| method_symbol.to_s }
    end

    def method_lines(method_name)
      method_node = Fast.search(Fast.ast(@source), "(def #{method_name})").first
      method_node.loc.first_line..method_node.loc.last_line
    end

    def method_source(method_name)
      method_node = Fast.search(Fast.ast(@source), "(def #{method_name})").first
      method_node.loc.expression.source
    end

    def insert_comment_before_method(method_name, comment)
      method_node = Fast.search(Fast.ast(@source), "(def #{method_name})").first
      method_node.loc.expression.source
      @source.insert(method_node.loc.expression.begin_pos, "# #{comment}\n")
    end

    def get_association_model_names
      @klass.reflect_on_all_associations.map do |association|
        association.klass.name.underscore
      end
    end

    private

    def get_concerns
      Fast.search(Fast.ast(@source), "(send nil include $())").each_slice(2).map do |_, concern_name_node|
        # underscore turns Namespaced::ExamPle into namespaced/exam_ple
        Concern.get_or_create(concern_name_node.loc.expression.source.underscore)
      end
    end
  end
end
