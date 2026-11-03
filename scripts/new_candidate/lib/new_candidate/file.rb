# frozen_string_literal: true

class File
  attr_reader :full_name, :source_path

  def destination_path
    throw NotImplementedError('This is an abstract class')
  end

  def extension
    File.extname(source_path)
  end

  def initialize(full_name, source_path)
    self.full_name = full_name.to_s.strip
    self.source_path = source_path.to_s.strip
  end

  def copy
    IO.copy_stream(source_path, destination_path)
  end

  def delete_source
    IO.delete(source_path)
  rescue Errno::ENOENT
    puts "Failed to delete (#{source_path})"
  end

  private

  attr_writer :full_name

  def source_path=(value)
    @source_path = File.join(TEMPLATE_PATH, value)
  end
end
