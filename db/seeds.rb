# Datos simulados mínimos para iniciar sesión con cada rol. Es idempotente: se puede correr varias veces.
# Nombres y RUT son ficticios. La contraseña común viene de SEED_PASSWORD y no se escribe en el código.

ucv = University.find_or_create_by!(slug: "ucv") do |university|
  university.name = "Universidad Central del Valle"
end

iusa = University.find_or_create_by!(slug: "iusa") do |university|
  university.name = "Instituto Universitario de Salud Austral"
end

password = ENV["SEED_PASSWORD"]

if password.blank?
  puts "SEED_PASSWORD no está definida: se crearon las universidades, pero no los usuarios demo."
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

# Minimal academic data per university, so each account sees its own courses and the
# other university's courses answer 404. Each university's records are created inside its tenant.
academic_data = [
  { university: ucv, admin: "admin@ucv.test", faculty: "Facultad de Ingeniería", code: "ICC1001", course: "Programación",
    staff: { "profesor@ucv.test" => "profesor", "ayudante@ucv.test" => "ayudante" }, students: [ "alumno@ucv.test" ] },
  { university: iusa, admin: "admin@iusa.test", faculty: "Facultad de Enfermería", code: "ENF1001", course: "Anatomía",
    staff: { "camila.torres@iusa.test" => "profesor" }, students: [] }
]

academic_data.each do |data|
  ActsAsTenant.with_tenant(data[:university]) do
    faculty = Faculty.find_or_create_by!(name: data[:faculty])
    term = Term.find_or_create_by!(name: "2026-2") do |new_term|
      new_term.starts_on = Date.new(2026, 8, 3)
      new_term.ends_on = Date.new(2026, 12, 11)
      new_term.current = true
    end
    course = Course.find_or_create_by!(code: data[:code]) do |new_course|
      new_course.name = data[:course]
      new_course.faculty = faculty
    end
    section = Section.find_or_create_by!(course: course, term: term, number: 1)

    data[:staff].each do |email, role|
      SectionStaff.find_or_create_by!(section: section, user: users.fetch(email), role: role) do |staff|
        staff.assigned_by = users.fetch(data[:admin])
      end
    end
    data[:students].each do |email|
      Enrollment.find_or_create_by!(section: section, student: users.fetch(email)) { |enrollment| enrollment.active = true }
    end
  end
end

puts "Datos académicos demo listos: #{academic_data.map { |data| "#{data[:code]} #{data[:course]}" }.join(', ')}"
