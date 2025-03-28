require 'date'
require 'active_support/core_ext/time'

class Main
  attr_reader :base, :file_path

  def initialize(base, file_path)
    @base       = base
    @file_path  = file_path
  end

  def execute
    segments  = parse_file_segments(@file_path)
    errors    = check_segments_data_integrity(segments)
    if errors.empty?
      parsed_segments     = parse_segments(segments)
      organized_segments  = organize_trips(parsed_segments)
      output              = format_trips(organized_segments)
    else
      output = format_errors(errors)
    end

    output

  end

  def parse_file_segments(file_path)
    #Reads the file and returns an array of segments
    #Each segment starts with 'SEGMENT:'
    #The 'segment' is the rest of the line

    segment_identificator = 'SEGMENT:'
    reservations = []
    
    File.readlines(file_path, chomp: true).each do |line|
      next unless line.include?(segment_identificator)
      line.slice!(segment_identificator)
      line.strip!
      reservations << line
    end

    reservations

  end

  def check_segments_data_integrity(segments)
    #Every segments first word should match with 'Flight', 'Train' or 'Hotel'
    #Every segment must have '->'
    #Every 'Flight' or 'Train' segment must have two iata, one valid date and two valid times
    #Every 'Hotel' segment must have one iata, two valid dates

    errors = []

    segments.each do |segment|
      type = get_segment_type(segment)
      unless valid_segment_types.include? type
        errors << segment
        next
      end
      unless segment.include?("->")
        errors << segment
        next
      end
      case type
      when 'Hotel'
        if get_segment_iatas(segment).count != 1 || get_segment_valid_dates(segment).count != 2 || get_segment_valid_times(segment).count != 0
          errors << segment
          next
        end
      when 'Flight', 'Train'
        if get_segment_iatas(segment).count != 2 || get_segment_valid_dates(segment).count != 1 || get_segment_valid_times(segment).count != 2
          errors << segment
          next
        end
      end
    end

    errors

  end

  def get_segment_type(segment)
    segment.split&.first
  end

  def valid_segment_types
    %w(Flight Train Hotel)
  end

  def get_segment_iatas(segment)
    iata_codes_regex  = /\b[A-Z]{3}\b/
    segment.scan(iata_codes_regex)
  end

  def get_segment_valid_dates(segment)
    valid_dates = []
    dates_regex = /\b\d{4}-\d{2}-\d{2}\b/
    segment.scan(dates_regex).each do |date|
      valid = !DateTime.parse(date).nil? rescue false
      valid_dates << date if valid
    end
    valid_dates
  end

  def get_segment_valid_times(segment)
    valid_times = []
    times_regex = /\b\d{2}:\d{2}\b/
    segment.scan(times_regex).each do |time|
      valid = !DateTime.parse(time).nil? rescue false
      valid_times << time if valid
    end
    valid_times
  end

  def parse_segments(segments)
    #Parses the segments into a structured format
    #Orders the segments by from_datetime

    reservations      = []

    segments.each do |segment|

      type          = get_segment_type(segment)
      datetimes     = get_from_to_datetimes(segment, type)
      from, to      = get_segment_iatas(segment)
      from_datetime = datetimes[:from_datetime]
      to_datetime   = datetimes[:to_datetime]

      segment_info = {
                      :type           => type,
                      :from           => from,
                      :from_datetime  => from_datetime,
                      :to             => to,
                      :to_datetime    => to_datetime
                    }
      reservations << segment_info
        
    end

    reservations.sort_by { |segment| segment[:from_datetime] }

  end

  def get_from_to_datetimes(segment, type)
    dates_regex = /\b(\d{4}-\d{2}-\d{2})\b/
    times_regex = /\b(\d{2}:\d{2})\b/

    from  = segment.split('->').first
    to    = segment.split('->').last

    from_date = from.scan(dates_regex)&.flatten&.first
    from_time = from.scan(times_regex)&.flatten&.first
    to_date   = to.scan(dates_regex)&.flatten&.first
    to_time   = to.scan(times_regex)&.flatten&.first

    to_date = (to_date.nil? && !from_date.empty?) ? from_date : to_date

    from_datetime = DateTime.parse("#{from_date} #{from_time}")
    to_datetime   = DateTime.parse("#{to_date} #{to_time}")

    if type == 'Hotel'
      from_datetime = from_datetime.end_of_day
      to_datetime   = to_datetime.beginning_of_day
    end

    {
      :from_datetime  => from_datetime,
      :to_datetime    => to_datetime
    }

  end

  def organize_trips(parsed_segments)
    #Segments are organized into trips
    #A trip is a collection of segments that are less than 24 hours apart

    trips = []
    current_trip = {
                    :title    => nil,
                    :segments => []
                    }

    parsed_segments.each_with_index do |parsed_segment, index|

      current_trip[:segments] << parsed_segment
      hours_of_difference = !parsed_segments[index+1].nil? ? (parsed_segments[index+1][:from_datetime] - parsed_segment[:to_datetime]) * 24 : 999

      if hours_of_difference > 24
        if parsed_segment[:type]=='Hotel'
          aux_to = parsed_segment[:type]=='Hotel' ? parsed_segment[:from] : parsed_segment[:to]
        else
          aux_to = (parsed_segment[:to] == @base) ? parsed_segment[:from] : parsed_segment[:to]
        end

        current_trip[:title] = "TRIP to #{aux_to}"
        trips << current_trip
        current_trip = {
                        :title    => nil,
                        :segments => []
                       }
      end

    end

    trips
    
  end

  def format_trips(organized_segments)
    #Formats the organized segments into a readable string
    #Each trip is separated by a new line

    output = ''

    organized_segments.each do |organized_segment|
      output += organized_segment[:title] + "\n"
      organized_segment[:segments].each do |segment|
        case segment[:type]
        when 'Hotel'
          output += "#{segment[:type]} at #{segment[:from]} on #{segment[:from_datetime]&.strftime('%Y-%m-%d')} to #{segment[:to_datetime]&.strftime('%Y-%m-%d')}\n"
        else
          output += "#{segment[:type]} from #{segment[:from]} to #{segment[:to]} at #{segment[:from_datetime]&.strftime('%Y-%m-%d %H:%M')} to #{segment[:to_datetime]&.strftime('%H:%M')}\n"
        end
      end
      output += "\n"
    end

    output

  end

  def format_errors(errors)
    #Formats the errors into a readable string
    #Each error is separated by a new line

    output = "Following lines could not be processed due to format failure: \n"

    errors.each do |error|
      output += error.to_s + "\n"
    end

    output

  end

end

if __FILE__ == $0
  base      = ENV['BASED']
  file_path = ARGV[0]
  main      = Main.new(base, file_path)
  output    = main.execute
  puts output
end