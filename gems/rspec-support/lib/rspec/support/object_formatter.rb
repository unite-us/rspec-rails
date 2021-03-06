module RSpec
  module Support
    # Provide additional output details beyond what `inspect` provides when
    # printing Time, DateTime, or BigDecimal
    # @api private
    class ObjectFormatter
      attr_accessor :max_formatted_output_length

      def initialize(max_formatted_output_length=200)
        @max_formatted_output_length = max_formatted_output_length
      end

      # Methods are deferred to a default instance of the class to maintain the interface
      # For example, calling ObjectFormatter.format is still possible
      @default_instance = new(200)

      ELLIPSIS = "..."

      def format(object)
        if max_formatted_output_length.nil?
          return prepare_for_inspection(object).inspect
        else
          formatted_object = prepare_for_inspection(object).inspect
          if formatted_object.length < max_formatted_output_length
            return formatted_object
          else
            beginning = formatted_object[0 .. max_formatted_output_length / 2]
            ending = formatted_object[-max_formatted_output_length / 2 ..-1]
            return beginning + ELLIPSIS + ending
          end
        end
      end

      def self.format(object)
        @default_instance.format(object)
      end

      # rubocop:disable MethodLength

      # Prepares the provided object to be formatted by wrapping it as needed
      # in something that, when `inspect` is called on it, will produce the
      # desired output.
      #
      # This allows us to apply the desired formatting to hash/array data structures
      # at any level of nesting, simply by walking that structure and replacing items
      # with custom items that have `inspect` defined to return the desired output
      # for that item. Then we can just use `Array#inspect` or `Hash#inspect` to
      # format the entire thing.
      def prepare_for_inspection(object)
        case object
        when Array
          return object.map { |o| prepare_for_inspection(o) }
        when Hash
          return prepare_hash(object)
        when Time
          inspection = format_time(object)
        else
          if defined?(DateTime) && DateTime === object
            inspection = format_date_time(object)
          elsif defined?(BigDecimal) && BigDecimal === object
            inspection = "#{object.to_s 'F'} (#{object.inspect})"
          elsif RSpec::Support.is_a_matcher?(object) && object.respond_to?(:description)
            inspection = object.description
          else
            return DelegatingInspector.new(object)
          end
        end

        InspectableItem.new(inspection)
      end
      # rubocop:enable MethodLength

      def self.prepare_for_inspection(object)
        @default_instance.prepare_for_inspection(object)
      end

      def prepare_hash(input)
        input.inject({}) do |hash, (k, v)|
          hash[prepare_for_inspection(k)] = prepare_for_inspection(v)
          hash
        end
      end

      def self.prepare_hash(input)
        @default_instance.prepare_hash(input)
      end

      TIME_FORMAT = "%Y-%m-%d %H:%M:%S"

      if Time.method_defined?(:nsec)
        def format_time(time)
          time.strftime("#{TIME_FORMAT}.#{"%09d" % time.nsec} %z")
        end
      else # for 1.8.7
        def format_time(time)
          time.strftime("#{TIME_FORMAT}.#{"%06d" % time.usec} %z")
        end
      end

      def self.format_time(time)
        @default_instance.format_time(time)
      end

      DATE_TIME_FORMAT = "%a, %d %b %Y %H:%M:%S.%N %z"
      # ActiveSupport sometimes overrides inspect. If `ActiveSupport` is
      # defined use a custom format string that includes more time precision.
      def format_date_time(date_time)
        if defined?(ActiveSupport)
          date_time.strftime(DATE_TIME_FORMAT)
        else
          date_time.inspect
        end
      end

      def self.format_date_time(date_time)
        @default_instance.format_date_time(date_time)
      end

      InspectableItem = Struct.new(:inspection) do
        def inspect
          inspection
        end

        def pretty_print(pp)
          pp.text inspection
        end
      end

      DelegatingInspector = Struct.new(:object) do
        def inspect
          if defined?(::Delegator) && ::Delegator === object
            "#<#{object.class}(#{ObjectFormatter.format(object.__getobj__)})>"
          else
            object.inspect
          end
        end

        def pretty_print(pp)
          pp.text inspect
        end
      end
    end
  end
end
