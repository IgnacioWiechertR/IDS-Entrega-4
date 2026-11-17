module CourseMaterialsHelper
  def material_display_title(material)
    material.title.presence || (material.file.attached? ? material.file.filename.to_s : "Material sin título")
  end
end
