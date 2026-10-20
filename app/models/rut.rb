# Chilean RUT: a 7 or 8 digit number and a check digit (0-9 or K), stored as "12345678-5" (A4).
module Rut
  FORMAT = /\A\d{7,8}-[\dK]\z/
  WEIGHTS = [ 2, 3, 4, 5, 6, 7 ].freeze

  module_function

  # Accepts what people usually type ("12.345.678-5", "12345678-5", "123456785", "k" in lowercase).
  def normalize(value)
    clean = value.to_s.upcase.delete("^0-9K")
    return clean if clean.length < 2

    "#{clean[0..-2]}-#{clean[-1]}"
  end

  def valid?(value)
    value.to_s.match?(FORMAT) && value[-1] == check_digit(value.split("-").first)
  end

  def build(number)
    "#{number}-#{check_digit(number)}"
  end

  # Module 11: weights 2..7 from the last digit, 11 is "0" and 10 is "K".
  def check_digit(number)
    sum = number.to_s.reverse.each_char.with_index.sum { |digit, index| digit.to_i * WEIGHTS[index % WEIGHTS.size] }
    { 11 => "0", 10 => "K" }.fetch(11 - (sum % 11)) { |digit| digit.to_s }
  end
end
