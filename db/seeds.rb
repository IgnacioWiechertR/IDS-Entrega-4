# Datos simulados mínimos para iniciar sesión con cada rol. Es idempotente: se puede correr varias veces.
# Nombres y RUT son ficticios. La contraseña común viene de SEED_PASSWORD y no se escribe en el código.
# Datos bsicos de facultad, cursos y secciones para pruebas.

ucv = University.find_or_create_by!(slug: "ucv") do |university|
  university.name = "Universidad Central del Valle"
end

iusa = University.find_or_create_by!(slug: "iusa") do |university|
  university.name = "Instituto Universitario de Salud Austral"
end

puts "Creando Periodos Academicos (Terms)..."
term_ucv = Term.find_or_create_by!(university: ucv, name: "Primer Semestre 2026") do |term|
  term.starts_on = Date.new(2026, 3, 1)
  term.ends_on = Date.new(2026, 7, 15)
  term.current = true
end

term_iusa = Term.find_or_create_by!(university: iusa, name: "Primer Semestre 2026") do |term|
  term.starts_on = Date.new(2026, 3, 10)
  term.ends_on = Date.new(2026, 7, 20)
  term.current = true
end

puts "Creando Facultades..."
fac_ingenieria = Faculty.find_or_create_by!(university: ucv, name: "Facultad de Ingenieria")
fac_salud = Faculty.find_or_create_by!(university: iusa, name: "Facultad de Ciencias de la Salud")

puts "Creando Cursos..."
course_icc = Course.find_or_create_by!(university: ucv, code: "ICC4204") do |course|
  course.faculty = fac_ingenieria
  course.name = "Ingenieria de Software"
end

course_anat = Course.find_or_create_by!(university: iusa, code: "ANAT101") do |course|
  course.faculty = fac_salud
  course.name = "Anatomia Humana"
end

puts "Creando Secciones..."
Section.find_or_create_by!(university: ucv, course: course_icc, term: term_ucv, number: 1)
Section.find_or_create_by!(university: ucv, course: course_icc, term: term_ucv, number: 2)
Section.find_or_create_by!(university: iusa, course: course_anat, term: term_iusa, number: 1)

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
  { email: "alumno@ucv.test",    first_name: "Matías",   last_name: "Herrera",  rut: "20145678-9", role: "alumno",         university: ucv }
]

demo_users.each do |attributes|
  User.find_or_create_by!(email: attributes[:email]) do |user|
    user.assign_attributes(attributes.except(:email))
    user.password = password
  end
end

puts "Usuarios demo listos: #{demo_users.map { |user| user[:email] }.join(', ')}"

puts "Asignando personal a las secciones..."

admin_ucv = User.find_by!(email: "admin@ucv.test")
profesor_ucv = User.find_by!(email: "profesor@ucv.test")

curso_icc = Course.find_by!(code: "ICC4204")
seccion_icc_1 = Section.find_by!(course: curso_icc, number: 1)

# Asignamos al Profesor
SectionStaff.find_or_create_by!(section: seccion_icc_1, user: profesor_ucv) do |staff|
  staff.role = "profesor" # Cambiado a "profesor" para pasar la validación del enum
  staff.assigned_by_id = admin_ucv.id
end

CourseCoordinator.find_or_create_by!(
  course: curso_icc,
  term: Term.find_by!(name: "Primer Semestre 2026", university: ucv),
  user: profesor_ucv
) do |cc|
  cc.assigned_by_id = admin_ucv.id
end
