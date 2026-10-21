require "test_helper"

class RutTest < ActiveSupport::TestCase
  test "acepta RUTs con su dígito verificador correcto" do
    %w[12345678-5 11111111-1 7654321-6 10000013-K 10000004-0].each do |rut|
      assert Rut.valid?(rut), "#{rut} debería ser válido"
    end
  end

  test "rechaza un dígito verificador incorrecto o un formato que no es RUT" do
    [ "12345678-9", "10000004-4", "1234-3", "123456789-0", "12345678", "abc", "" ].each do |rut|
      assert_not Rut.valid?(rut), "#{rut.inspect} debería ser inválido"
    end
  end

  test "normaliza puntos, espacios, guion y la K minúscula" do
    assert_equal "12345678-5", Rut.normalize(" 12.345.678-5 ")
    assert_equal "12345678-5", Rut.normalize("123456785")
    assert_equal "10000013-K", Rut.normalize("10.000.013-k")
    assert_equal "", Rut.normalize("")
  end

  test "agrega el dígito verificador a un número" do
    assert_equal "12345678-5", Rut.build(12_345_678)
    assert_equal "10000013-K", Rut.build(10_000_013)
    assert_equal "10000004-0", Rut.build(10_000_004)
  end
end
