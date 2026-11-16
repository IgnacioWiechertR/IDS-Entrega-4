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

# Más alumnos para comparar resultados; cada universidad tiene su propio equipo.
[
  [ ucv, "sofia@ucv.test", "Sofía", "Vega", 21000001, "alumno" ],
  [ ucv, "tomas@ucv.test", "Tomás", "Silva", 21000002, "alumno" ],
  [ iusa, "ayudante@iusa.test", "Diego", "Pérez", 22000001, "ayudante" ],
  [ iusa, "alumno@iusa.test", "Antonia", "Díaz", 22000002, "alumno" ],
  [ iusa, "lucas@iusa.test", "Lucas", "Reyes", 22000003, "alumno" ],
  [ iusa, "isidora@iusa.test", "Isidora", "León", 22000004, "alumno" ]
].each do |university, email, first_name, last_name, number, role|
  demo_users << { university: university, email: email, first_name: first_name, last_name: last_name,
                  rut: Rut.build(number), role: role }
end

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
           students: [ [ "ICC1001", 1, "alumno@ucv.test" ], [ "ICC1001", 1, "sofia@ucv.test" ],
                       [ "ICC1001", 1, "tomas@ucv.test" ] ],
           coordinators: [ [ "ICC4204", "profesor@ucv.test" ] ] },
  iusa => { admin: "admin@iusa.test",
            staff: [ [ "ANAT101", 1, "camila.torres@iusa.test", "profesor" ],
                     [ "ANAT101", 1, "ayudante@iusa.test", "ayudante" ] ],
            students: [ [ "ANAT101", 1, "alumno@iusa.test" ], [ "ANAT101", 1, "lucas@iusa.test" ],
                        [ "ANAT101", 1, "isidora@iusa.test" ] ],
            coordinators: [ [ "ANAT101", "camila.torres@iusa.test" ] ] }
}

assignments.each do |university, data|
  ActsAsTenant.with_tenant(university) do
    current_term = Term.find_by!(name: "2026-2")
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

# Los escenarios solo añaden datos: una nueva carga conserva contraseñas, notas y asistencia editadas.
puts "Creando escenarios de asistencia y notas..."
scenarios = {
  ucv => { course: "ICC1001", professor: "profesor@ucv.test", assistant: "ayudante@ucv.test",
           students: %w[alumno@ucv.test sofia@ucv.test tomas@ucv.test], scores: [ 5.5, 6.2, 4.0 ] },
  iusa => { course: "ANAT101", professor: "camila.torres@iusa.test", assistant: "ayudante@iusa.test",
            students: %w[alumno@iusa.test lucas@iusa.test isidora@iusa.test], scores: [ 6.0, 4.8, 3.5 ] }
}
class_dates = (0...8).map { |week| Date.new(2026, 8, 10) + week.weeks }.reject(&:future?)
evaluation_examples = [
  [ "Demo T8 · Control publicado", "publicada", Date.new(2026, 9, 7) ],
  [ "Demo T8 · Control pendiente", "pendiente", Date.new(2026, 9, 14) ],
  [ "Demo T8 · Control rechazado", "rechazada", Date.new(2026, 9, 21) ]
]

scenarios.each do |university, data|
  ActsAsTenant.with_tenant(university) do
    section = Section.find_by!(course: Course.find_by!(code: data[:course]),
                               term: Term.find_by!(name: "2026-2"), number: 1)
    professor = users.fetch(data[:professor])
    assistant = users.fetch(data[:assistant])
    students = data[:students].map { |email| users.fetch(email) }

    class_dates.each_with_index do |held_on, week|
      session = section.attendance_sessions.find_or_create_by!(held_on: held_on) do |record|
        record.recorded_by = professor
      end
      students.each_with_index do |student, index|
        next unless section.enrollments.exists?(student: student, active: true)

        session.attendance_records.find_or_create_by!(student: student) do |record|
          record.status = (index + week) % 4 == 0 ? "ausente" : "presente"
        end
      end
    end

    # No se reducen ponderaciones existentes para hacer espacio a los ejemplos.
    missing = evaluation_examples.count { |name, _status, _date| !section.evaluations.exists?(name: name) }
    if section.evaluations.sum(:weight) + missing * 20 > 100
      puts "Se omiten las notas demo de #{data[:course]}: no queda ponderación disponible."
      next
    end

    Evaluation.transaction do
      evaluation_examples.each do |name, status, date|
        evaluation = section.evaluations.find_or_create_by!(name: name) do |record|
          record.weight = 20
          record.due_on = date
          record.rubric = "Pauta demo: comprensión del contenido y aplicación correcta del procedimiento."
        end
        students.each_with_index do |student, index|
          next unless section.enrollments.exists?(student: student, active: true)

          evaluation.grades.find_or_create_by!(student: student) do |grade|
            grade.score = data[:scores][index]
            grade.status = status
            grade.entered_by = assistant
            grade.reviewed_by = professor unless status == "pendiente"
            grade.feedback = "Retroalimentación de ejemplo: revisa el procedimiento de la segunda pregunta."
            grade.rejection_comment = "Revisar la suma de puntajes antes de reenviar." if status == "rechazada"
          end
        end
      end
    end
  end
end

puts "Datos académicos demo listos: #{academic_structure.values.flat_map { |data| data[:courses].map { |code, (name, _)| "#{code} #{name}" } }.join(', ')}"
