module Llmtest
  class Concern
    attr_reader :file_name

    @concerns = []
    def self.get_or_create(file_name)
      concern = @concerns.find { |c| c.file_name == file_name }
      if concern.nil?
        concern = Concern.new(file_name)
        @concerns << concern
      end
      concern
    end

    def self.all
      @concerns
    end

    def initialize(file_name)
      @file_name = file_name
    end

    def name
      file_name.camelize
    end

    def path
      Rails.root.join("app", "models", "concerns", "#{file_name}.rb")
    end

    def source
      path.read
    end
  end
end
