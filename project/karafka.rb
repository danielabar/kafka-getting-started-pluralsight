# frozen_string_literal: true

# This is a non-Rails example app!

ENV['KARAFKA_ENV'] ||= 'development'
Bundler.require(:default, ENV['KARAFKA_ENV'])

# Zeitwerk custom loader for loading the app components before the whole
# Karafka framework configuration
APP_LOADER = Zeitwerk::Loader.new

%w[
  lib
  app/consumers
].each(&APP_LOADER.method(:push_dir))

APP_LOADER.setup
APP_LOADER.eager_load

# App class
class App < Karafka::App
  setup do |config|
    config.concurrency = 5
    config.max_wait_time = 1_000
    config.kafka = { 'bootstrap.servers': ENV['KAFKA_HOST'] || '127.0.0.1:9092' }
  end
end

Karafka.producer.monitor.subscribe(WaterDrop::Instrumentation::LoggerListener.new(Karafka.logger))
Karafka.monitor.subscribe(Karafka::Instrumentation::LoggerListener.new)
Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

# See https://karafka.io/docs/Topics-management-and-administration/
App.consumer_groups.draw do
  consumer_group :batched_group do
    topic :example do
      consumer ExampleConsumer
    end

    topic :xml_data do
      config(partitions: 2)
      consumer XmlMessagesConsumer
      deserializer XmlDeserializer.new
    end

    topic :counters do
      config(partitions: 1)
      consumer CountersConsumer
    end

    # Commenting out ping/pong because they go into infinite loop
    # topic :ping do
    #   # 1 day in ms
    #   config(partitions: 5, 'retention.ms': 86_400_000)
    #   consumer Pong::PingConsumer
    # end

    # Commenting out ping/pong because they go into infinite loop
    # topic :pong do
    #   # 1 day in ms
    #   config(partitions: 5, 'retention.ms': 86_400_000)
    #   consumer Pong::PongConsumer
    # end
  end
end
