# frozen_string_literal: true

namespace :waterdrop do
  desc 'Generates messages to Kafka server'
  task :send do
    3.times do
      message = "<message><new>home-#{rand}</new></message>"
      Karafka.producer.produce_async(topic: 'xml_data', payload: message)
    end

    10.times do
      message = { 'number' => rand }.to_json
      # @note You can send messages with sync producer again
      Karafka.producer.produce_async(topic: 'counters', payload: message)
    end

    # Sends the initial ping to start ping-pong within Karafka
    # message = { 'hits' => 0 }.to_json
    # Karafka.producer.produce_async(topic: 'ping', payload: message)

    Karafka.producer.close
  end

  desc 'Generate many messages for ordering demo'
  task :send_order do
    100.times do |i|
      message = { 'number' => i }.to_json
      key = SecureRandom.hex(4)
      puts "Sending message #{i}, key #{key}"
      Karafka.producer.produce_async(topic: 'ordering_demo', key: key, payload: message)
    end
    # Karafka.producer.close
  end
end
