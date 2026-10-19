# Datos simulados mínimos para iniciar sesión con cada rol. Es idempotente: se puede correr varias veces.
# Nombres y RUT son ficticios. La contraseña común viene de SEED_PASSWORD y no se escribe en el código.

ucv = University.find_or_create_by!(slug: "ucv") do |university|
  university.name = "Universidad Central del Valle"
end

iusa = University.find_or_create_by!(slug: "iusa") do |university|
  university.name = "Instituto Universitario de Salud Austral"
end

Section.destroy_all
Course.destroy_all
Faculty.destroy_all
Term.destroy_all
SectionStaff.destroy_all

puts "Creando Periodos Academicos (Terms)..."
term_ucv = Term.create!(
  university: ucv,
  name: "Primer Semestre 2026",
  starts_on: Date.new(2026, 3, 1),
  ends_on: Date.new(2026, 7, 15),
  current: true
)

term_iusa = Term.create!(
  university: iusa,
  name: "Primer Semestre 2026",
  starts_on: Date.new(2026, 3, 10),
  ends_on: Date.new(2026, 7, 20),
  current: true
)

puts "Creando Facultades..."
fac_ingenieria = Faculty.create!(university: ucv, name: "Facultad de Ingenieria")
fac_salud = Faculty.create!(university: iusa, name: "Facultad de Ciencias de la Salud")

puts "Creando Cursos..."
course_icc = Course.create!(
  university: ucv,
  faculty: fac_ingenieria,
  code: "ICC4204",
  name: "Ingenieria de Software"
)

course_anat = Course.create!(
  university: iusa,
  faculty: fac_salud,
  code: "ANAT101",
  name: "Anatomia Humana"
)

puts "Creando Secciones..."
Section.create!(
  university: ucv,
  course: course_icc,
  term: term_ucv,
  number: 1
)

Section.create!(
  university: ucv,
  course: course_icc,
  term: term_ucv,
  number: 2
)

Section.create!(
  university: iusa,
  course: course_anat,
  term: term_iusa,
  number: 1
)

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
SectionStaff.create!(
  section: seccion_icc_1,
  user: profesor_ucv,
  role: "Profesor Titular",
  assigned_by_id: admin_ucv.id
)
