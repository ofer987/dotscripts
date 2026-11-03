# frozen_string_literal: true

class Notes < ::Mustache
  self.template_file = File.join(TEMPLATE_PATH, "#{SOURCE_NAME}_#{NOTES_PATH}")

  attr_reader :full_name, :role, :date, :time, :hacker_rank_url, :wd5_url, :additional_interviewers, :team

  def initialize(full_name, role, date, time, hacker_rank_url, wd5_url, additional_interviewers, team)
    # Required attributes
    self.full_name = full_name.to_s.strip
    self.role = role.to_s.strip
    self.date = date.to_s.strip
    self.time = time.to_s.strip
    self.hacker_rank_url = hacker_rank_url.to_s.strip
    self.wd5_url = wd5_url.to_s.strip

    # Optional attributes
    self.additional_interviewers = additional_interviewers
    self.team = team.to_s.strip
  end

  def mkdir
    Dir.mkdir(full_name) unless Dir.exist? full_name
  end

  def notes_path
    File.join(full_name, "#{full_name}_notes.md")
  end

  def write
    IO.write(notes_path, render)
  end

  private

  def additional_interviewers=(value)
    result = value.to_s.strip
      .split(',')
      .map(&:strip)

    if result.size == 0
      @additional_interviewers = "alone"
    elsif result.size == 1
      @additional_interviewers = result[0]
    elsif result.size == 2
      @additional_interviewers = "#{result[0]} and #{result[1]}"
    else
      @additional_interviewers = "#{result[0..-2].join(', ')}, and #{result[-1]}"
    end
  end

  attr_writer :full_name, :role, :date, :time, :hacker_rank_url, :wd5_url, :team
end
