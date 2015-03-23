require 'csv2avro/schema'
require 'csv2avro/avro_file'
require 'csv'

class CSV2Avro
  class Converter
    attr_reader :input, :csv_options, :converter_options, :avro, :schema

    def initialize(input, schema, output, options)
      @input = input
      @schema = schema

      @csv_options = {
        :headers => true,
        :skip_blanks => true
      }

      @csv_options[:col_sep] = options[:delimiter] if options[:delimiter]
      @converter_options = options

      @avro = CSV2Avro::AvroFile.new(schema, output)

      init_header_converter
    end

    def perform
      defaults_hash = schema.defaults_hash if converter_options[:write_defaults]

      CSV.parse(input, csv_options) do |row|
        row_as_hash = row.to_hash

        convert_fields!(row_as_hash)

        if converter_options[:write_defaults]
          add_defaults_to_hash!(row_as_hash, defaults_hash)
        end

        avro.write(row_as_hash)
      end

      avro.flush
      avro.io
    end

    private

    def convert_fields!(hash)
      fields_to_convert = schema.types_hash.select{ |key, value| value != 'string' }

      fields_to_convert.each do |key, value|
        case value
        when 'int'
          hash[key] = Integer(hash[key]) rescue nil
        when 'float', 'double'
          hash[key] = Float(hash[key]) rescue nil
        when 'boolean'
          hash[key] = parse_boolean(hash[key])
        when 'array'
          hash[key] = parse_array(hash[key])
        end
      end
    end

    def parse_boolean(value)
      return true  if value == true  || value =~ (/^(true|t|yes|y|1)$/i)
      return false if value == false || value =~ (/^(false|f|no|n|0)$/i)
      nil
    end

    def parse_array(value)
      delimiter = converter_options[:array_delimiter] || ','

      value.split(delimiter) if value
    end

    def add_defaults_to_hash!(hash, defaults_hash)
      # Add default values to nil cells
      hash.each do |key, value|
        hash[key] = defaults_hash[key] if value.nil?
      end

      #Add default values to missing columns
      defaults_hash.each  do |key, value|
        hash[key] = defaults_hash[key]  unless hash.has_key?(key)
      end

      hash
    end

    def init_header_converter
      aliases_hash = schema.aliases_hash

      CSV::HeaderConverters[:aliases] = lambda do |header|
          aliases_hash[header] || header
      end

      csv_options[:header_converters] = :aliases
    end
  end
end
