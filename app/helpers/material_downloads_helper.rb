module MaterialDownloadsHelper
  def material_download_link(course, material)
    if material.file.attached?
      link_to "Descargar", course_material_download_path(course, material), download: true,
        data: { turbo: false }, aria: { label: "Descargar #{material.file.filename}" },
        class: "rounded-md border border-slate-300 px-4 py-2 text-sm font-semibold text-indigo-700 hover:bg-slate-50"
    else
      tag.span "Archivo no disponible", class: "text-sm text-slate-500"
    end
  end
end
