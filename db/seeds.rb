# Datos simulados para la demo. Es idempotente: se puede correr varias veces.
# Nombres y RUT son ficticios. La contraseña común viene de SEED_PASSWORD y no se escribe en el código.

ucv = University.find_or_create_by!(slug: "ucv") do |university|
  university.name = "Universidad Central del Valle"
end

iusa = University.find_or_create_by!(slug: "iusa") do |university|
  university.name = "Instituto Universitario de Salud Austral"
end

# Estructura académica de cada universidad, creada dentro de su universidad (A3).
# Solo puede haber un período vigente por universidad: 2026-1 queda cerrado y 2026-2 es el vigente.
puts "Creando períodos, facultades, asignaturas y secciones..."
academic_structure = {
  ucv => { faculty: "Facultad de Ingeniería",
           courses: { "ICC4204" => [ "Ingeniería de Software", 2 ], "ICC1001" => [ "Programación", 1 ] } },
  iusa => { faculty: "Facultad de Ciencias de la Salud",
            courses: { "ANAT101" => [ "Anatomía Humana", 1 ] } }
}

academic_structure.each do |university, data|
  ActsAsTenant.with_tenant(university) do
    Term.find_or_create_by!(name: "2026-1") do |term|
      term.starts_on = Date.new(2026, 3, 2)
      term.ends_on = Date.new(2026, 7, 17)
      term.current = false
    end
    current_term = Term.find_or_create_by!(name: "2026-2") do |term|
      term.starts_on = Date.new(2026, 8, 3)
      term.ends_on = Date.new(2026, 12, 11)
      term.current = true
    end

    faculty = Faculty.find_or_create_by!(name: data[:faculty])
    data[:courses].each do |code, (name, sections)|
      course = Course.find_or_create_by!(code: code) do |new_course|
        new_course.name = name
        new_course.faculty = faculty
      end
      (1..sections).each { |number| Section.find_or_create_by!(course: course, term: current_term, number: number) }
    end
  end
end

password = ENV["SEED_PASSWORD"]

if password.blank?
  puts "SEED_PASSWORD no está definida: se creó la estructura académica, pero no los usuarios demo."
  return
end

demo_users = [
  { email: "director@sga.test",  first_name: "Carolina", last_name: "Fuentes", rut: "12345678-5", role: "director",       university: nil },
  { email: "admin@ucv.test",     first_name: "Andrés",   last_name: "Molina",   rut: "15678234-3", role: "administrativo", university: ucv },
  { email: "admin@iusa.test",    first_name: "Paula",    last_name: "Rivas",    rut: "17234561-1", role: "administrativo", university: iusa },
  { email: "profesor@ucv.test",  first_name: "Ricardo",  last_name: "Soto",     rut: "18452397-3", role: "profesor",       university: ucv },
  { email: "ayudante@ucv.test",  first_name: "Valentina", last_name: "Rojas",   rut: "19873452-7", role: "ayudante",       university: ucv },
  { email: "alumno@ucv.test",    first_name: "Matías",   last_name: "Herrera",  rut: "20145678-9", role: "alumno",         university: ucv },
  # The same person in both universities: one account per university, same RUT (A3).
  { email: "camila.torres@ucv.test",  first_name: "Camila", last_name: "Torres", rut: "16789012-1", role: "profesor", university: ucv },
  { email: "camila.torres@iusa.test", first_name: "Camila", last_name: "Torres", rut: "16789012-1", role: "profesor", university: iusa }
]

users = demo_users.to_h do |attributes|
  user = User.find_or_create_by!(email: attributes[:email]) do |new_user|
    new_user.assign_attributes(attributes.except(:email))
    new_user.password = password
  end
  [ attributes[:email], user ]
end

puts "Usuarios demo listos: #{users.keys.join(', ')}"

# Equipo docente, alumnos inscritos y coordinadores del período vigente, por universidad.
# Así cada cuenta ve sus propios cursos y los de la otra universidad responden 404 (A3).
puts "Asignando personal, alumnos y coordinadores..."
assignments = {
  ucv => { admin: "admin@ucv.test",
           staff: [ [ "ICC4204", 1, "profesor@ucv.test", "profesor" ],
                    [ "ICC1001", 1, "profesor@ucv.test", "profesor" ],
                    [ "ICC1001", 1, "ayudante@ucv.test", "ayudante" ] ],
           students: [ [ "ICC1001", 1, "alumno@ucv.test" ] ],
           coordinators: [ [ "ICC4204", "profesor@ucv.test" ] ] },
  iusa => { admin: "admin@iusa.test",
            staff: [ [ "ANAT101", 1, "camila.torres@iusa.test", "profesor" ] ],
            students: [],
            coordinators: [] }
}

assignments.each do |university, data|
  ActsAsTenant.with_tenant(university) do
    current_term = Term.find_by!(current: true)
    admin = users.fetch(data[:admin])
    section_of = ->(code, number) { Section.find_by!(course: Course.find_by!(code: code), term: current_term, number: number) }

    data[:staff].each do |code, number, email, role|
      SectionStaff.find_or_create_by!(section: section_of.call(code, number), user: users.fetch(email), role: role) do |staff|
        staff.assigned_by = admin
      end
    end
    data[:students].each do |code, number, email|
      Enrollment.find_or_create_by!(section: section_of.call(code, number), student: users.fetch(email)) do |enrollment|
        enrollment.active = true
      end
    end
    data[:coordinators].each do |code, email|
      CourseCoordinator.find_or_create_by!(course: Course.find_by!(code: code), term: current_term, user: users.fetch(email)) do |coordinator|
        coordinator.assigned_by = admin
      end
    end
  end
end

# Asistencia semanal de las primeras 8 semanas del período vigente en las secciones con alumnos (B6),
# para que la demo muestre porcentajes. Fechas y marcas son fijas: correr los seeds de nuevo no cambia nada.
puts "Registrando asistencia..."
class_dates = (0...8).map { |week| Date.new(2026, 8, 10) + week.weeks }

[ ucv, iusa ].each do |university|
  ActsAsTenant.with_tenant(university) do
    SectionStaff.where(university: university, role: "profesor").includes(:user).each do |staff|
      students = staff.section.active_students.to_a
      next if students.empty?

      class_dates.each_with_index do |held_on, week|
        statuses = students.each_with_index.to_h { |student, index| [ student.id.to_s, (index + week) % 4 == 0 ? "ausente" : "presente" ] }
        recorder = AttendanceRecorderService.new(section: staff.section, held_on: held_on, recorded_by: staff.user)
        raise "No se pudo registrar la asistencia del #{held_on}: #{recorder.session.errors.full_messages.to_sentence}" unless recorder.call(statuses)
      end
    end
  end
end

puts "Datos académicos demo listos: #{academic_structure.values.flat_map { |data| data[:courses].map { |code, (name, _)| "#{code} #{name}" } }.join(', ')}"
