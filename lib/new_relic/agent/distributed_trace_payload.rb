# encoding: utf-8
# This file is distributed under New Relic's license terms.
# See https://github.com/newrelic/rpm/blob/master/LICENSE for complete details.
require 'json'
require 'base64'
require 'set'

require 'new_relic/agent/distributed_trace_transport_type'

module NewRelic
  module Agent
    #
    # This class contains properties related to distributed traces.
    # To obtain an instance, call
    # {DistributedTracing#create_distributed_trace_payload}
    #
    # @api public
    class DistributedTracePayload
      VERSION =[0, 1].freeze
      PARENT_TYPE = "App".freeze
      POUND = '#'.freeze

      # Key names for serialization
      VERSION_KEY                = 'v'.freeze
      DATA_KEY                   = 'd'.freeze
      PARENT_TYPE_KEY            = 'ty'.freeze
      PARENT_ACCOUNT_ID_KEY      = 'ac'.freeze
      PARENT_APP_KEY             = 'ap'.freeze
      TRUSTED_ACCOUNT_KEY        = 'tk'.freeze
      ID_KEY                     = 'id'.freeze
      TX_KEY                     = 'tx'.freeze
      TRACE_ID_KEY               = 'tr'.freeze
      SAMPLED_KEY                = 'sa'.freeze
      TIMESTAMP_KEY              = 'ti'.freeze
      PRIORITY_KEY               = 'pr'.freeze

      class << self

        def for_transaction transaction
          return nil unless connected?

          payload = new
          payload.version = VERSION
          payload.parent_type = PARENT_TYPE
          payload.parent_account_id = Agent.config[:account_id]
          payload.parent_app_id = Agent.config[:primary_application_id]

          assign_trusted_account_key(payload, payload.parent_account_id)

          payload.id = current_segment_id(transaction)
          payload.transaction_id = transaction.guid
          payload.timestamp = (Time.now.to_f * 1000).round
          payload.trace_id = transaction.trace_id
          payload.sampled = transaction.sampled?
          payload.priority = transaction.priority

          payload
        end

        def from_json serialized_payload
          raw_payload = JSON.parse serialized_payload
          return raw_payload if raw_payload.nil?
          payload_data = raw_payload[DATA_KEY]

          payload = new
          payload.version             = raw_payload[VERSION_KEY]
          payload.parent_type         = payload_data[PARENT_TYPE_KEY]
          payload.parent_account_id   = payload_data[PARENT_ACCOUNT_ID_KEY]
          payload.parent_app_id       = payload_data[PARENT_APP_KEY]
          payload.trusted_account_key = payload_data[TRUSTED_ACCOUNT_KEY]
          payload.timestamp           = payload_data[TIMESTAMP_KEY]
          payload.id                  = payload_data[ID_KEY]
          payload.transaction_id      = payload_data[TX_KEY]
          payload.trace_id            = payload_data[TRACE_ID_KEY]
          payload.sampled             = payload_data[SAMPLED_KEY]
          payload.priority            = payload_data[PRIORITY_KEY]

          payload
        end

        def from_http_safe http_safe_payload
          decoded_payload = Base64.strict_decode64 http_safe_payload
          from_json decoded_payload
        end

        def major_version_matches?(payload)
          payload.version[0] == VERSION[0]
        end

        private

        def assign_trusted_account_key payload, account_id
          trusted_account_key = Agent.config[:trusted_account_key]

          if account_id != trusted_account_key
            payload.trusted_account_key = trusted_account_key
          end
        end

        def current_segment_id(transaction)
          if Agent.config[:'span_events.enabled'] && transaction.sampled? &&
              transaction.current_segment
            transaction.current_segment.guid
          end
        end

        def connected?
          Agent.instance.connected?
        end
      end

      attr_accessor :version,
                    :parent_type,
                    :parent_account_id,
                    :parent_app_id,
                    :trusted_account_key,
                    :id,
                    :transaction_id,
                    :trace_id,
                    :sampled,
                    :priority,
                    :timestamp

      alias_method :sampled?, :sampled

      attr_reader :caller_transport_type

      def caller_transport_type= type
        @caller_transport_type = DistributedTraceTransportType.from type
      end

      def initialize
        @caller_transport_type = DistributedTraceTransportType::UNKNOWN
      end

      # Represent this payload as a raw JSON string.
      #
      # @return [String] Payload translated to JSON
      #
      # @api public
      def text
        result = {
          VERSION_KEY => version
        }

        result[DATA_KEY] = {
          PARENT_TYPE_KEY       => parent_type,
          PARENT_ACCOUNT_ID_KEY => parent_account_id,
          PARENT_APP_KEY        => parent_app_id,
          TX_KEY                => transaction_id,
          TRACE_ID_KEY          => trace_id,
          SAMPLED_KEY           => sampled,
          PRIORITY_KEY          => priority,
          TIMESTAMP_KEY         => timestamp,
        }

        result[DATA_KEY][ID_KEY]              = id if id
        result[DATA_KEY][TRUSTED_ACCOUNT_KEY] = trusted_account_key if trusted_account_key

        JSON.dump(result)
      end

      # Encode this payload as a string suitable for passing via an
      # HTTP header.
      #
      # @return [String] Payload translated to JSON and encoded for
      #                  inclusion in headers
      #
      # @api public
      def http_safe
        Base64.strict_encode64 text
      end
    end
  end
end
