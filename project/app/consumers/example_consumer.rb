# frozen_string_literal: true

# Example consumer that prints messages payloads
class ExampleConsumer < ApplicationConsumer
  def consume
    messages.each do |message|
      key = message.key
      payload = message.payload
      # payload = message.raw_payload
      timestamp = message.timestamp
      partition = message.partition
      puts "Key: #{key}, Payload: #{payload}, Timestamp: #{timestamp}, Partition: #{partition}"
    end
  end

  # Run anything upon partition being revoked
  # def revoked
  # end

  # Define here any teardown things you want when Karafka server stops
  # def shutdown
  # end
end
