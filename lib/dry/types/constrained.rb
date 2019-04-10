# frozen_string_literal: true

require 'dry/types/decorator'
require 'dry/types/constraints'
require 'dry/types/constrained/coercible'

module Dry
  module Types
    class Constrained
      include Type
      include Decorator
      include Builder
      include Printable
      include Dry::Equalizer(:type, :options, :rule, :meta, inspect: false)

      # @return [Dry::Logic::Rule]
      attr_reader :rule

      # @param [Type] type
      # @param [Hash] options
      def initialize(type, options)
        super
        @rule = options.fetch(:rule)
      end

      # @param [Object] input
      # @return [Object]
      # @raise [ConstraintError]
      def call(input, &block)
        if block_given?
          if rule[input]
            type.(input, &block)
          else
            yield
          end
        else
          result = rule.(input)

          if result.success?
            type.(input, &block)
          else
            raise ConstraintError.new(result, input)
          end
        end
      end
      alias_method :[], :call

      # @param [Object] input
      # @param [#call,nil] block
      # @yieldparam [Failure] failure
      # @yieldreturn [Result]
      # @return [Logic::Result, Result]
      # @return [Object] if block given and try fails
      def try(input, &block)
        result = rule.(input)

        if result.success?
          type.try(input, &block)
        else
          failure = failure(input, ConstraintError.new(result, input))
          block_given? ? yield(failure) : failure
        end
      end

      # @param [Object] value
      # @return [Boolean]
      def valid?(value)
        rule.(value).success? && type.valid?(value)
      end

      # @param [Hash] options
      #   The options hash provided to {Types.Rule} and combined
      #   using {&} with previous {#rule}
      # @return [Constrained]
      # @see Dry::Logic::Operators#and
      def constrained(options)
        with(rule: rule & Types.Rule(options))
      end

      # @return [true]
      def constrained?
        true
      end

      # @param [Object] value
      # @return [Boolean]
      def ===(value)
        valid?(value)
      end

      def lax
        type.lax
      end

      # @api public
      #
      # @see Nominal#to_ast
      def to_ast(meta: true)
        [:constrained, [type.to_ast(meta: meta),
                        rule.to_ast,
                        meta ? self.meta : EMPTY_HASH]]
      end

      private

      # @param [Object] response
      # @return [Boolean]
      def decorate?(response)
        super || response.is_a?(Constructor)
      end
    end
  end
end
