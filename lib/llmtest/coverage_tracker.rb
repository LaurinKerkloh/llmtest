module Llmtest
  class CoverageTracker
    attr_reader :coverage_path, :source_path, :relevant_lines
    def initialize(coverage_path, source_path, relevant_lines)
      @coverage_path = coverage_path
      @source_path = source_path
      @relevant_lines = relevant_lines
    end

    def record_coverage
      coverage = parse_coverage_file

      @line_coverage = get_line_coverage(coverage)
      @branch_coverage = get_branch_coverage(coverage)
    end

    def newly_covered
      coverage = parse_coverage_file

      lines_newly_covered = []
      puts self
      get_line_coverage(coverage).each_with_index do |line_coverage, index|
        puts "line_coverage at index #{index}: #{line_coverage}"
        if line_coverage >= 1 && @line_coverage[index] == 0
          lines_newly_covered << index + 1
          @line_coverage[index] = line_coverage
        end
      end

      branches_newly_covered = []
      get_branch_coverage(coverage).each_with_index do |branch, index|
        if branch["coverage"] >= 1 && @branch_coverage[index]["coverage"] == 0
          branches_newly_covered << branch
          @branch_coverage[index]["coverage"] = branch["coverage"]
        end
      end

      [lines_newly_covered, branches_newly_covered]
    end

    def fully_covered?
      all_lines_covered = uncovered_lines.empty?
      all_branches_covered = uncovered_branches.empty?

      all_lines_covered && all_branches_covered
    end

    def to_s
      "lines: #{@line_coverage}\nbranches: #{@branch_coverage}"
    end

    def uncovered_lines(in_original_file: false)
      uncovered_lines = @line_coverage.filter_map.with_index { |coverage, index| index + 1 if coverage == 0 }

      return uncovered_lines unless in_original_file

      uncovered_lines.map { |line| line + @relevant_lines.begin - 1 }
    end

    def uncovered_branches(in_original_file: false)
      unvovered_branches = @branch_coverage.filter_map { |branch| branch if branch["coverage"] == 0 }

      return unvovered_branches unless in_original_file

      unvovered_branches.map { |branch| branch["start_line"] + @relevant_lines.begin }
    end

    private

    def parse_coverage_file
      JSON.parse(@coverage_path.read).dig("coverage", @source_path.to_s)
    end

    def get_line_coverage(file_coverage)
      # the lines array is 0-indexed so we shift the relevant line numbers by 1
      file_coverage["lines"][(@relevant_lines.begin - 1)..(@relevant_lines.end - 1)]
    end

    def get_branch_coverage(file_coverage)
      branches = file_coverage["branches"].select { |branch| relevant_lines.include?(branch["start_line"]) }
      branches.map { |branch| branch["start_line"] = branch["start_line"] - @relevant_lines.begin }
    end
  end
end
