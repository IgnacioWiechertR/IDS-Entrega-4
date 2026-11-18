require "test_helper"

class MaterialStorageServiceTest < ActiveSupport::TestCase
  test "cada universidad usa su servicio S3 aunque el predeterminado sea el de la otra" do
    assert_equal :amazon_u1, MaterialStorageService.for(courses(:one), default: :amazon_u2)
    ActsAsTenant.with_tenant(universities(:iusa)) do
      assert_equal :amazon_u2, MaterialStorageService.for(courses(:two), default: :amazon_u1)
    end
  end

  test "desarrollo y pruebas conservan el servicio local configurado" do
    assert_equal :test, MaterialStorageService.for(courses(:one), default: :test)
    assert_equal :local, MaterialStorageService.for(courses(:one), default: :local)
  end

  test "con S3 activado una universidad sin servicio no utiliza el bucket de otra" do
    university = University.new(name: "Sin configuración", slug: "sin-configuracion")
    course = Course.new(university: university)

    assert_raises MaterialStorageService::UniversityNotConfigured do
      MaterialStorageService.for(course, default: :amazon_u1)
    end
  end
end
