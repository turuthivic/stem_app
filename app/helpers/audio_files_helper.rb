module AudioFilesHelper
  def time_duration_format(seconds)
    return "0:00" if seconds.nil? || seconds.zero?

    minutes = (seconds / 60).floor
    remaining_seconds = (seconds % 60).floor

    "#{minutes}:#{remaining_seconds.to_s.rjust(2, '0')}"
  end
end
