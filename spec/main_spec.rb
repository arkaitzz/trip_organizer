require 'rspec'
require_relative '../main'

RSpec.describe Main do

  let(:base) { 'SVQ' }
  let(:file_path) { 'test_input.txt' }
  let(:main) { Main.new(base, file_path) }

  describe '#initialize' do
    it 'sets the base and file_path attributes' do
      expect(main.base).to eq(base)
      expect(main.file_path).to eq(file_path)
    end
  end

  describe '#parse_file_segments' do
    it 'parses segments from the file correctly' do
      allow(File).to receive(:readlines).with(file_path, chomp: true).and_return([
        "SEGMENT: Flight SVQ 2023-03-02 06:40 -> BCN 09:10",
        "SEGMENT: Hotel BCN 2023-01-05 -> 2023-01-10"
      ])
      result = main.parse_file_segments(file_path)
      expect(result).to eq([
        "Flight SVQ 2023-03-02 06:40 -> BCN 09:10",
        "Hotel BCN 2023-01-05 -> 2023-01-10"
      ])
    end
  end

  describe '#check_segments_data_integrity' do
    it 'returns errors for invalid segments' do
      segments = [
        "Flight SVQ 2023-03-02 06:40 -> BCN",
        "Hotel BCN 2023-01-05 ->"
      ]
      result = main.check_segments_data_integrity(segments)
      expect(result).to eq(segments)
    end

    it 'returns an empty array for valid segments' do
      segments = [
        "Flight SVQ 2023-03-02 06:40 -> BCN 09:10",
        "Hotel BCN 2023-01-05 -> 2023-01-10"
      ]
      result = main.check_segments_data_integrity(segments)
      expect(result).to eq([])
    end
  end

  describe '#parse_segments' do
    it 'parses valid segments into structured data' do
      segments = [
        "Flight SVQ 2023-03-02 06:40 -> BCN 09:10",
        "Hotel BCN 2023-01-05 -> 2023-01-10"
      ]
      result = main.parse_segments(segments)
      expect(result).to include(
        hash_including(type: 'Flight', from: 'SVQ', to: 'BCN'),
        hash_including(type: 'Hotel', from: 'BCN')
      )
    end
  end

  describe '#organize_trips' do
    it 'organizes parsed segments into trips' do
      parsed_segments = [
        { type: 'Flight', from: 'SVQ', to: 'BCN', from_datetime: DateTime.parse('2023-03-02T06:40'), to_datetime: DateTime.parse('2023-03-02T09:10') },
        { type: 'Hotel', from: 'BCN', from_datetime: DateTime.parse('2023-01-05T23:59'), to_datetime: DateTime.parse('2023-01-10T00:00') }
      ]
      result = main.organize_trips(parsed_segments)
      expect(result).to include(
        hash_including(title: 'TRIP to BCN', segments: parsed_segments)
      )
    end
  end

  describe '#format_trips' do
    it 'formats organized trips into a readable string' do
      organized_segments = [
        {
          title: 'TRIP to BCN',
          segments: [
            { type: 'Flight', from: 'SVQ', to: 'BCN', from_datetime: DateTime.parse('2023-03-02T06:40'), to_datetime: DateTime.parse('2023-03-02T09:10') },
            { type: 'Hotel', from: 'BCN', from_datetime: DateTime.parse('2023-01-05T23:59'), to_datetime: DateTime.parse('2023-01-10T00:00') }
          ]
        }
      ]
      result = main.format_trips(organized_segments)
      expect(result).to include("TRIP to BCN")
      expect(result).to include("Flight from SVQ to BCN at 2023-03-02 06:40 to 09:10")
      expect(result).to include("Hotel at BCN on 2023-01-05 to 2023-01-10")
    end
  end

  describe '#format_errors' do
    it 'formats errors into a readable string' do
      errors = [
        "Invalid segment 1",
        "Invalid segment 2"
      ]
      result = main.format_errors(errors)
      expect(result).to include("Following lines could not be processed due to format failure:")
      expect(result).to include("Invalid segment 1")
      expect(result).to include("Invalid segment 2")
    end
  end
  
end