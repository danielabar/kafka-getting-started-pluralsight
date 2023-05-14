# frozen_string_literal: true

# Example consumer that prints messages payloads
class OrderingDemoConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      key = message.key
      payload = message.payload
      timestamp = message.timestamp
      partition = message.partition
      offset = message.offset
      puts "Key: #{key}, Payload: #{payload}, Timestamp: #{timestamp}, Partition: #{partition}, Offset: #{offset}"
    end
  end
end
