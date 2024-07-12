module Llmtest
  class CoverageTracker
    attr_reader :coverage_path, :source_path, :relevant_lines
    def initialize(coverage_path, source_path, relevant_lines)
      @coverage_path = coverage_path
      @source_path = source_path
      @relevant_lines = relevant_lines
    end

    def record_initial_coverage
      coverage = parse_coverage_file

      @line_coverage = get_line_coverage(coverage)
      @branch_coverage = get_branch_coverage(coverage)
    end

    def newly_covered
      coverage = parse_coverage_file

      lines_newly_covered = []
      get_line_coverage(coverage).each_with_index do |line_coverage, index|
        if line_coverage == 1 && @line_coverage[index] == 0
          lines_newly_covered << index + 1
          @line_coverage[index] = 1
        end
      end

      branches_newly_covered = []
      get_branch_coverage(coverage).each_with_index do |branch, index|
        if branch["coverage"] == 1 && @branch_coverage[index]["coverage"] == 0
          branches_newly_covered << branch
          @branch_coverage[index]["coverage"] = 1
        end
      end

      [lines_newly_covered, branches_newly_covered]
    end

    def fully_covered?
      all_lines_covered = @line_coverage.none? { |line| line == 0 }
      all_branches_covered = @branch_coverage.none? { |branch| branch["coverage"] == 0 }
      all_lines_covered && all_branches_covered
    end

    def to_s
      "lines: #{@line_coverage}\nbranches: #{@branch_coverage}"
    end

    private

    def parse_coverage_file
      JSON.parse(@coverage_path.read).dig("coverage", @source_path.to_s)
    end

    def get_line_coverage(file_coverage)
      file_coverage["lines"][@relevant_lines]
    end

    def get_branch_coverage(file_coverage)
      file_coverage["branches"].select { |branch| relevant_lines.include?(branch["start_line"]) }
    end
  end
end
