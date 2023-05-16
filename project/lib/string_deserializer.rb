# frozen_string_literal: true

class StringDeserializer
  def call(params)
    params.raw_payload.to_s
  end
end
