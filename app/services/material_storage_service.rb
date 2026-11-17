# Reuses T5's two S3 services when remote storage is enabled. Local development and
# tests keep their configured disk service; no bucket credentials are changed here.
class MaterialStorageService
  class UniversityNotConfigured < StandardError; end

  UNIVERSITY_SERVICES = { "ucv" => :amazon_u1, "iusa" => :amazon_u2 }.freeze

  def self.for(course, default: Rails.configuration.active_storage.service)
    service = default&.to_sym
    return service unless UNIVERSITY_SERVICES.value?(service)

    UNIVERSITY_SERVICES.fetch(course&.university&.slug) do
      raise UniversityNotConfigured, "University has no configured material storage service"
    end
  end
end
