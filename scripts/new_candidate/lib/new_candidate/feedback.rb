# frozen_string_literal: true

class Feedback < Notes
  attr_reader :full_name, :source_path

  def destination_path
    File.join(full_name, "#{full_name}_feedback#{extension}")
  end
end
