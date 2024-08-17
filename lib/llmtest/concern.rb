module Llmtest
  # Class to represent a concern in the Rails application.
  class Concern
    attr_reader :file_name

    @concerns = []

    # Retrieve a concern object by its file name or create a new concern if it does not exist.
    #
    # @param file_name [String] Name of the concern file. Example: "validatable" or "searchable"
    def self.get_or_create(file_name)
      concern = @concerns.find { |c| c.file_name == file_name }
      if concern.nil?
        concern = Concern.new(file_name)
        @concerns << concern
      end
      concern
    end

    # Retrieve all unique concerns from an array of models.
    #
    # @param models [Array<Llmtest::Model>] Array of models.
    # @return [Array<Llmtest::Concern>] Array of concerns.
    def self.from_models(models)
      models.flat_map(&:concerns).uniq
    end

    # @param file_name [String] Name of the concern file.
    def initialize(file_name)
      @file_name = file_name
    end

    # Returns the name of the concern class. Example: "Validatable" or "Searchable"
    #
    # @return [String] Name of the concern class.
    def name
      file_name.camelize
    end

    # Returns the path to the concern file.
    #
    # @return [Pathname] Path to the concern file.
    def path
      Rails.root.join("app", "models", "concerns", "#{file_name}.rb")
    end

    # Returns the source code of the concern file.
    #
    # @return [String] Source code of the concern file.
    def source
      path.read
    end
  end
end
