require 'time'
require 'date'
require 'json'
require 'uuidtools'
require 'microsoft_kiota_abstractions'


module MicrosoftKiotaSerializationJson
  class JsonParseNode
    include MicrosoftKiotaAbstractions::ParseNode
    def initialize(node)
      @current_node = node
    end

    def get_string_value
      @current_node.to_s
    end

    def get_boolean_value
      @current_node
    end

    def get_number_value
      @current_node.to_i
    end

    def get_float_value
      @current_node.to_f
    end

    def get_guid_value
      UUIDTools::UUID.parse(@current_node)
    end

    def get_date_value
      Date.parse(@current_node)
    end

    def get_time_value()
      Time.parse(@current_node)
    end

    def get_date_time_value()
      DateTime.parse(@current_node)
    end

    def get_duration_value()
      MicrosoftKiotaAbstractions::ISODuration.new(@current_node)
    end

    def get_collection_of_primitive_values(type)
      @current_node.map do |object|
        next if object.nil?

        current_parse_node = JsonParseNode.new(object)
        case type
        when String
          current_parse_node.get_string_value
        when Float
          current_parse_node.get_float_value
        when Integer
          current_parse_node.get_float_value
        when "Boolean"
          current_parse_node.get_float_value
        when DateTime
          current_parse_node.get_date_time_value
        when Time
          current_parse_node.get_time_value
        when Date
          current_parse_node.get_date_value
        when MicrosoftKiotaAbstractions::ISODuration
          current_parse_node.get_duration_value
        when UUIDTools::UUID
          current_parse_node.get_guid_value
        else
          current_parse_node.get_string_value
        end
      end
    rescue StandardError => e
      raise e.class, `Failed to fetch #{type} type`
    end

    def get_collection_of_object_values(factory)
      raise StandardError, 'Factory cannot be null' if factory.nil?
      @current_node.map do |object|
        next if object.nil?

        current_parse_node = JsonParseNode.new(object)
        current_parse_node.get_object_value(factory)
      end
    end

    def get_object_value(factory)
      raise StandardError, 'Factory cannot be null' if factory.nil?
      item = factory.call(self)
      assign_field_values(item)
      item
    rescue StandardError => e
      raise e.class, 'Error during deserialization'
    end

    def assign_field_values(item)
      fields = item.get_field_deserializers
      @current_node.each do |k, v|
        next if v.nil?

        deserializer = fields[k]
        if deserializer
          deserializer.call(JsonParseNode.new(v))
        elsif item.additional_data
          item.additional_data[k] = v
        else
          item.additional_data = Hash.new(k => v)
        end
      end
    end

    def get_enum_values(_type)
      raw_values = get_string_value
      raw_values.split(',').map(&:strip)
    end

    def get_enum_value(type)
      items = get_enum_values(type).map(&:to_sym)
      items[0] if items.length.positive?
    end

    def get_child_node(name)
      raise StandardError, 'Name cannot be null' if name.nil? || name.empty?
      raw_value = @current_node[name]
      return JsonParseNode.new(raw_value) if raw_value
    end
  end
end
