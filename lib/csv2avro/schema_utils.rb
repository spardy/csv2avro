class CSV2Avro
  class SchemaUtils
    attr_reader :schema

    def initialize(schema)
      @schema = schema
    end

    def column_names_with_type(data_type)
      primitive_fields = schema.fields.select do |field|
        field.type.type_sym == data_type
      end.map(&:name)

      union_fields = schema.fields.select do |field|
        field.type.type_sym == :union
      end.select do |field|
        field.type.schemas.any? {|schema| schema.type_sym == data_type}
      end.map(&:name)

      (primitive_fields + union_fields)
    end

    def defaults_hash
      Hash[
        schema.fields.map{ |field| [field.name, field.default] }
      ]
    end

    # TODO: Change this when the avro gem starts to support aliases
    def self.aliases_hash(schema_string)
      schema_as_json = JSON.parse(schema_string)

      Hash[
        schema_as_json['fields'].select{ |field| field['aliases'] }.flat_map do |field|
          field['aliases'].map { |one_alias| [one_alias, field['name']]}
        end
      ]
    end
  end
end
