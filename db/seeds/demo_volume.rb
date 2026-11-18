# Datos de volumen para la demo: muchas cuentas, cursos, notas, asistencia, anuncios, material y notificaciones en
# las dos universidades, para recorrer todas las funcionalidades con datos realistas.
#
# - db/seeds.rb lo carga después de las cuentas demo de T8, y solo si hay SEED_PASSWORD.
# - Es determinista: no usa azar (salvo el carácter de cada archivo de material), así que una base nueva siempre
#   queda igual. Una segunda carga solo agrega lo que falta: conserva contraseñas, notas, asistencia y ediciones.
# - No toca las secciones de T8 (ICC1001-1 y ANAT101-1): sus tests cuentan alumnos, clases y notas exactas.
# - Notas, asistencia y notificaciones son miles de filas: se insertan con insert_all sobre sus índices únicos
#   (ON CONFLICT DO NOTHING), así la carga tarda segundos y nunca reemplaza un registro existente. Las filas se
#   construyen con las mismas reglas de los modelos, y el test de volumen comprueba que siguen siendo válidas.
# - SEED_ALUMNOS cambia cuántos alumnos se generan por universidad (por defecto 150 en UCV y 120 en IUSA).
class DemoVolumeSeeds
  CURRENT_TERM = "2026-2".freeze
  PAST_TERM = "2026-1".freeze

  # Secciones de T8, que esta carga no modifica.
  DEMO_SECTIONS = { "ucv" => [ "ICC1001", 1 ], "iusa" => [ "ANAT101", 1 ] }.freeze

  UNIVERSITIES = {
    "ucv" => {
      domain: "ucv.test",
      main_admin: "admin@ucv.test",
      students: 150,
      staff: { administrativo: 2, profesor: 12, ayudante: 10 },
      # Base de los RUT generados: cada rol tiene su propio rango, lejos de los RUT de las cuentas de T8.
      ruts: { administrativo: 14_100_000, profesor: 14_200_000, ayudante: 24_100_000, alumno: 24_200_000 },
      # Facultad => { código => [ nombre, secciones en el período vigente ] }
      faculties: {
        "Facultad de Ingeniería" => {
          "ICC1001" => [ "Programación", 3 ], "ICC2002" => [ "Estructuras de Datos", 2 ],
          "ICC3003" => [ "Bases de Datos", 2 ], "ICC4204" => [ "Ingeniería de Software", 2 ],
          "MAT1001" => [ "Cálculo I", 3 ]
        },
        "Facultad de Economía y Negocios" => {
          "ADM2001" => [ "Contabilidad", 2 ], "ECO1001" => [ "Introducción a la Economía", 2 ]
        },
        "Facultad de Humanidades" => { "HUM1001" => [ "Taller de Escritura", 2 ] }
      },
      # Cursos con una sección cerrada en 2026-1, para "Cursos anteriores" y el filtro por período.
      past_courses: %w[ICC1001 ICC2002 MAT1001 ECO1001],
      # Huecos a propósito, para que D6 (completitud de datos) tenga algo que mostrar. ICC4204-2 queda sin
      # profesor también para la demo de A22: profesor@ucv.test, que coordina ICC4204, asigna ahí a Camila Torres.
      without_professor: [ [ "ICC4204", 2 ] ],
      without_students: [ [ "HUM1001", 2 ] ],
      without_attendance: [ [ "ADM2001", 2 ] ],
      # Las cuentas de T8 participan en más cursos, para que su recorrido muestre más que una sección.
      professors: { [ "ICC2002", 1 ] => "profesor@ucv.test", [ "ICC3003", 1 ] => "camila.torres@ucv.test" },
      assistants: { [ "ICC2002", 1 ] => "ayudante@ucv.test" },
      enrollments: {
        "alumno@ucv.test" => %w[MAT1001 ICC2002 ECO1001],
        "sofia@ucv.test" => %w[MAT1001],
        "tomas@ucv.test" => %w[MAT1001 HUM1001],
        # A23: un ayudante también estudia otros cursos.
        "ayudante@ucv.test" => %w[MAT1001]
      }
    },
    "iusa" => {
      domain: "iusa.test",
      main_admin: "admin@iusa.test",
      students: 120,
      staff: { administrativo: 2, profesor: 10, ayudante: 8 },
      ruts: { administrativo: 14_300_000, profesor: 14_400_000, ayudante: 24_300_000, alumno: 24_400_000 },
      faculties: {
        "Facultad de Ciencias de la Salud" => {
          "ANAT101" => [ "Anatomía Humana", 2 ], "BIO101" => [ "Biología Celular", 2 ],
          "ENF201" => [ "Fundamentos de Enfermería", 2 ], "FIS101" => [ "Fisiología", 2 ]
        },
        "Facultad de Medicina" => { "FAR201" => [ "Farmacología", 2 ], "MED301" => [ "Semiología", 1 ] },
        "Facultad de Psicología" => { "PSI101" => [ "Psicología General", 2 ], "PSI202" => [ "Psicología del Desarrollo", 2 ] }
      },
      past_courses: %w[ANAT101 BIO101 FIS101 PSI101],
      without_professor: [ [ "FAR201", 2 ] ],
      without_students: [ [ "PSI202", 2 ] ],
      without_attendance: [ [ "ENF201", 2 ] ],
      professors: { [ "FIS101", 1 ] => "camila.torres@iusa.test" },
      assistants: { [ "BIO101", 1 ] => "ayudante@iusa.test" },
      enrollments: {
        "alumno@iusa.test" => %w[FIS101 BIO101 PSI101],
        "lucas@iusa.test" => %w[FIS101],
        "isidora@iusa.test" => %w[FIS101 PSI101],
        "ayudante@iusa.test" => %w[PSI101]
      }
    }
  }.freeze

  # [ nombre, ponderación, fecha ]. El período vigente suma 90 %: deja 10 % para crear una evaluación en la demo.
  CURRENT_EVALUATIONS = [
    [ "Control 1", 10, Date.new(2026, 8, 24) ],
    [ "Tarea 1", 10, Date.new(2026, 9, 7) ],
    [ "Prueba 1", 20, Date.new(2026, 9, 28) ],
    [ "Control 2", 10, Date.new(2026, 10, 13) ],
    [ "Tarea 2", 10, Date.new(2026, 10, 26) ],
    [ "Prueba 2", 15, Date.new(2026, 11, 9) ],
    [ "Examen", 15, Date.new(2026, 12, 7) ]
  ].freeze

  PAST_EVALUATIONS = [
    [ "Control 1", 15, Date.new(2026, 3, 30) ],
    [ "Tarea 1", 15, Date.new(2026, 4, 20) ],
    [ "Prueba 1", 25, Date.new(2026, 5, 11) ],
    [ "Tarea 2", 15, Date.new(2026, 6, 8) ],
    [ "Examen", 30, Date.new(2026, 7, 6) ]
  ].freeze

  # Las notas se publican tres semanas después de la fecha de la evaluación; antes están en revisión.
  PUBLISHED_AFTER = 21

  FIRST_NAMES = %w[
    Martina Benjamín Sofía Vicente Florencia Agustín Isidora Joaquín Emilia Tomás Antonia Maximiliano Catalina
    Lucas Josefa Cristóbal Fernanda Matías Valentina Felipe Javiera Diego Constanza Nicolás Trinidad Sebastián
    Amanda Gaspar Renata Ignacio Rocío Alonso Paz Bastián Ignacia Facundo Colomba Simón Elisa Andrés
  ].freeze

  LAST_NAMES = %w[
    González Muñoz Rojas Díaz Pérez Soto Contreras Silva Martínez Sepúlveda Morales Rodríguez López Fuentes
    Hernández Torres Araya Flores Espinoza Valenzuela Castillo Tapia Reyes Gutiérrez Castro Pizarro Álvarez
    Vásquez Sánchez Fernández Ramírez Carrasco Gómez Cortés Herrera Núñez Jara Vergara Rivera Figueroa
  ].freeze

  FEEDBACK = [
    "Buen desarrollo; revisa la justificación de la pregunta 3.",
    "Procedimiento correcto, pero faltó concluir con el resultado pedido.",
    "Muy buen trabajo, ordenado y completo.",
    "Revisa los conceptos de la unidad 2 antes de la próxima evaluación.",
    "Respuesta parcial en la segunda parte; el planteamiento era correcto.",
    "Excelente análisis y redacción clara."
  ].freeze

  REJECTION_COMMENTS = [
    "Revisa la suma de puntajes de la pregunta 2 antes de reenviar.",
    "Faltan las notas de dos alumnos y hay un puntaje sobre el máximo.",
    "La pauta usada no es la última versión: corrige con la pauta publicada."
  ].freeze

  MATERIALS = [
    "Programa del curso", "Apuntes · Unidad 1", "Apuntes · Unidad 2",
    "Guía de ejercicios 1", "Guía de ejercicios 2", "Pauta Prueba 1"
  ].freeze

  def initialize(password:, students: nil, today: Date.current)
    @password = password
    @students = students
    @today = today
  end

  def call
    # A single hash for every generated account: they all share SEED_PASSWORD anyway, and hashing it hundreds of
    # times with bcrypt would take minutes.
    digest = Devise::Encryptor.digest(User, @password)

    UNIVERSITIES.map do |slug, config|
      University.find_by!(slug: slug).then do |university|
        Loader.new(university, config, digest: digest, students: @students || config[:students], today: @today).call
      end
    end
  end

  # Loads one university, always inside its own tenant (A3).
  class Loader
    ROLE_EMAIL = { administrativo: "admin%02d", profesor: "profesor%02d", ayudante: "ayudante%02d", alumno: "alumno%03d" }.freeze
    ROLE_NAME_OFFSET = { administrativo: 300, profesor: 200, ayudante: 100, alumno: 0 }.freeze

    def initialize(university, config, digest:, students:, today:)
      @university = university
      @config = config
      @digest = digest
      @students_count = students
      @today = today
      @slug = university.slug
    end

    def call
      ActsAsTenant.with_tenant(@university) do
        build_structure
        build_accounts
        load_taken_roles
        staff_sections
        enroll_students
        assign_coordinators
        build_evaluations_and_grades
        build_attendance
        build_announcements
        build_materials
        build_notifications
      end
      puts "#{@university.name}: #{User.where(university: @university).count} cuentas, " \
           "#{@current_sections.size + @past_sections.size} secciones."
    end

    private

    # Structure ------------------------------------------------------------------------------------------------

    def build_structure
      @current_term = Term.find_by!(name: DemoVolumeSeeds::CURRENT_TERM)
      @past_term = Term.find_by!(name: DemoVolumeSeeds::PAST_TERM)
      @courses = {}

      @config[:faculties].each do |faculty_name, courses|
        faculty = Faculty.find_or_create_by!(name: faculty_name)
        courses.each do |code, (name, sections)|
          course = Course.find_or_create_by!(code: code) do |new_course|
            new_course.name = name
            new_course.faculty = faculty
          end
          @courses[code] = course
          (1..sections).each { |number| Section.find_or_create_by!(course: course, term: @current_term, number: number) }
          if @config[:past_courses].include?(code)
            Section.find_or_create_by!(course: course, term: @past_term, number: 1)
          end
        end
      end

      @course_codes = @courses.keys.sort
      @current_sections = sections_of(@current_term)
      @past_sections = sections_of(@past_term)
    end

    def sections_of(term)
      Section.where(term: term, course: @courses.values).includes(:course).to_a
        .sort_by { |section| [ section.course.code, section.number ] }
    end

    def demo?(section) = DemoVolumeSeeds::DEMO_SECTIONS[@slug] == [ section.course.code, section.number ]

    def listed?(key, section) = @config[key].include?([ section.course.code, section.number ])

    def course_index(section) = @course_codes.index(section.course.code)

    # Accounts -------------------------------------------------------------------------------------------------

    def build_accounts
      @admin = User.find_by!(email: @config[:main_admin])
      @admins = (1..@config[:staff][:administrativo]).map { |index| account(:administrativo, index) }
      @professors = (1..@config[:staff][:profesor]).map { |index| account(:profesor, index) }
      @assistants = (1..@config[:staff][:ayudante]).map { |index| account(:ayudante, index) }
      # One in fifteen students has a deleted (deactivated) account, with history only in the past term.
      @students = (1..@students_count).map { |index| account(:alumno, index, active: !(index % 15).zero?) }
    end

    def account(role, index, active: true)
      email = "#{format(ROLE_EMAIL.fetch(role), index)}@#{@config[:domain]}"
      User.find_by(email: email) || create_account(role, index, email, active)
    end

    def create_account(role, index, email, active)
      name_index = index + ROLE_NAME_OFFSET.fetch(role) + (@slug == "ucv" ? 0 : 17)
      user = User.new(
        email: email, role: role.to_s, university: @university, active: active,
        first_name: DemoVolumeSeeds::FIRST_NAMES[(name_index * 7) % DemoVolumeSeeds::FIRST_NAMES.size],
        last_name: "#{surname(name_index * 11)} #{surname(name_index * 17 + 5)}",
        rut: Rut.build(@config[:ruts].fetch(role) + index)
      )
      user.encrypted_password = @digest

      # Every rule of User applies except the password presence: the shared hash replaces the password.
      user.validate
      raise ActiveRecord::RecordInvalid, user if (user.errors.attribute_names - [ :password ]).any?

      user.save!(validate: false)
      user
    end

    # Two different surnames: 11 and 17 never give the same position among the 40 surnames.
    def surname(position) = DemoVolumeSeeds::LAST_NAMES[position % DemoVolumeSeeds::LAST_NAMES.size]

    def demo_account(email) = User.find_by!(email: email)

    # Number that identifies a person in the formulas below: the RUT without its check digit, stable across loads.
    def number_of(user) = user.rut.split("-").first.to_i

    # Roles: one per person, course and term (OneRolePerCourse) ------------------------------------------------

    def load_taken_roles
      @taken = Hash.new { |hash, key| hash[key] = Set.new }
      sections = (@current_sections + @past_sections).index_by(&:id)

      SectionStaff.where(section_id: sections.keys).pluck(:section_id, :user_id).each do |section_id, user_id|
        @taken[key_for(sections[section_id])] << user_id
      end
      Enrollment.where(section_id: sections.keys).pluck(:section_id, :student_id).each do |section_id, user_id|
        @taken[key_for(sections[section_id])] << user_id
      end
    end

    def key_for(section) = [ section.course_id, section.term_id ]

    def free_in_course?(section, user) = !@taken[key_for(section)].include?(user.id)

    # The first account of the pool, starting at `start`, that has no role in the course yet.
    def pick(pool, start, section)
      pool.size.times.lazy.map { |offset| pool[(start + offset) % pool.size] }.find { |user| free_in_course?(section, user) }
    end

    # Staff, enrollments and coordinators ----------------------------------------------------------------------

    def staff_sections
      (@config[:professors] || {}).each { |(code, number), email| assign(section_for(code, number), demo_account(email), "profesor") }
      (@config[:assistants] || {}).each { |(code, number), email| assign(section_for(code, number), demo_account(email), "ayudante") }

      @current_sections.each_with_index do |section, index|
        next if demo?(section) || listed?(:without_professor, section)

        start = course_index(section) * 3 + section.number
        assign(section, pick(@professors, start, section), "profesor")
        missing_assistants(section, index % 3 == 0 ? 2 : 1).times do |extra|
          assign(section, pick(@assistants, index * 2 + extra, section), "ayudante")
        end
      end

      @past_sections.each_with_index do |section, index|
        assign(section, pick(@professors, course_index(section) * 5 + 1, section), "profesor")
        missing_assistants(section, 1).times { assign(section, pick(@assistants, index * 3 + 1, section), "ayudante") }
      end
    end

    # A second load must not add more ayudantes: pick skips whoever already has a role in the course, so it would
    # always find someone new.
    def missing_assistants(section, wanted)
      [ wanted - SectionStaff.where(section: section, role: "ayudante").count, 0 ].max
    end

    def section_for(code, number)
      @current_sections.find { |section| section.course.code == code && section.number == number }
    end

    def assign(section, user, role)
      return unless section && user
      return if SectionStaff.exists?(section: section, user: user)
      return if role == "profesor" && SectionStaff.exists?(section: section, role: "profesor")
      return unless free_in_course?(section, user)

      SectionStaff.create!(section: section, user: user, role: role, assigned_by: @admin)
      @taken[key_for(section)] << user.id
    end

    def enroll(section, student, active: true)
      return unless section && student
      return if Enrollment.exists?(section: section, student: student)
      return unless free_in_course?(section, student)

      Enrollment.create!(section: section, student: student, active: active)
      @taken[key_for(section)] << student.id
    end

    def enroll_students
      targets = @current_sections.reject { |section| demo?(section) || listed?(:without_students, section) }
                                 .group_by { |section| section.course.code }

      @config[:enrollments].each do |email, codes|
        codes.each { |code| enroll(targets.fetch(code).first, demo_account(email)) }
      end

      # Each active student takes about three in ten courses; one enrollment in 29 is withdrawn (inactive).
      @students.select(&:active?).each do |student|
        number = number_of(student)
        @course_codes.each_with_index do |code, course_index|
          sections = targets[code]
          next if sections.blank? || (number * 7 + course_index * 13) % 10 >= 3

          enroll(sections[(number / 10 + course_index) % sections.size], student, active: (number + course_index) % 29 != 0)
        end
      end

      # A23: generated ayudantes also study one course where they do not assist.
      @assistants.each_with_index do |assistant, index|
        code = @course_codes[(index * 3 + 1) % @course_codes.size]
        enroll(targets[code]&.first, assistant)
      end

      # Past term: a quarter of the students, plus every deleted account, which keeps this history.
      @past_sections.each_with_index do |section, index|
        @students.each do |student|
          next if student.active? && (number_of(student) + index) % 4 != 0

          enroll(section, student)
        end
      end
    end

    def assign_coordinators
      [ [ @current_sections, @current_term ], [ @past_sections, @past_term ] ].each do |sections, term|
        sections.group_by(&:course).each do |course, course_sections|
          next if CourseCoordinator.exists?(course: course, term: term)

          coordinator = course_sections.filter_map { |section| professor_of(section) }.first
          next unless coordinator

          CourseCoordinator.create!(course: course, term: term, user: coordinator, assigned_by: @admin)
        end
      end
    end

    def professor_of(section) = SectionStaff.find_by(section: section, role: "profesor")&.user

    def assistant_of(section) = SectionStaff.where(section: section, role: "ayudante").order(:id).first&.user

    # Evaluations and grades -----------------------------------------------------------------------------------

    def build_evaluations_and_grades
      (@current_sections + @past_sections).each_with_index do |section, index|
        next if demo?(section)

        professor = professor_of(section)
        students = section.active_students.to_a
        next if professor.nil? || students.empty?

        templates = section.term_id == @past_term.id ? DemoVolumeSeeds::PAST_EVALUATIONS : DemoVolumeSeeds::CURRENT_EVALUATIONS
        missing = templates.reject { |name, _, _| section.evaluations.exists?(name: name) }.sum { |_, weight, _| weight }
        if section.evaluations.sum(:weight) + missing > 100
          puts "Se omiten las evaluaciones de #{section.course.code}-#{section.number}: no queda ponderación disponible."
          next
        end

        entered_by = assistant_of(section) || professor
        templates.each_with_index do |(name, weight, due_on), position|
          evaluation = section.evaluations.find_or_create_by!(name: name) do |record|
            record.weight = weight
            record.due_on = due_on
            record.rubric = "Pauta de #{name}: dominio de los contenidos de la unidad, procedimiento y comunicación de resultados."
          end
          status = grade_status(evaluation.due_on, index)
          next unless status

          rows = students.filter_map do |student|
            number = number_of(student)
            # A pending evaluation in one section in four is still being entered: some students have no grade yet.
            next if status == "pendiente" && index % 4 == 1 && number % 5 == 0

            grade_row(evaluation, student, number, position, index, status, entered_by, professor)
          end
          Grade.insert_all(rows, unique_by: :index_grades_on_evaluation_id_and_student_id) if rows.any?
        end
      end
    end

    # nil before the evaluation; then pending (or rejected in one section in three) until it is published.
    def grade_status(due_on, section_index)
      return if due_on > @today
      return "publicada" if due_on + DemoVolumeSeeds::PUBLISHED_AFTER <= @today

      (section_index % 3).zero? ? "rechazada" : "pendiente"
    end

    def grade_row(evaluation, student, number, position, section_index, status, entered_by, professor)
      ability = 30 + (number * 37) % 36                                   # 3,0 to 6,5, in tenths
      noise = ((number * 13 + position * 29 + section_index * 7) % 17) - 8 # -0,8 to +0,8
      score = ((ability + noise).clamp(10, 70) / 10.0).round(1)
      exam = evaluation.name.start_with?("Prueba", "Examen")

      {
        evaluation_id: evaluation.id, student_id: student.id, university_id: @university.id,
        score: score, status: status,
        points: exam ? ((score - 1) / 6 * 60).round(2) : nil,
        feedback: (number + position) % 4 == 3 ? nil : DemoVolumeSeeds::FEEDBACK[(number + position) % DemoVolumeSeeds::FEEDBACK.size],
        rejection_comment: status == "rechazada" ? DemoVolumeSeeds::REJECTION_COMMENTS[section_index % DemoVolumeSeeds::REJECTION_COMMENTS.size] : nil,
        entered_by_id: entered_by.id,
        reviewed_by_id: status == "pendiente" ? nil : professor.id
      }
    end

    # Attendance -----------------------------------------------------------------------------------------------

    def build_attendance
      (@current_sections + @past_sections).each_with_index do |section, index|
        next if demo?(section) || listed?(:without_attendance, section)

        professor = professor_of(section)
        students = section.active_students.to_a
        next if professor.nil? || students.empty?

        rows = class_dates(section, index).each_with_index.flat_map do |held_on, week|
          session = section.attendance_sessions.find_or_create_by!(held_on: held_on) { |record| record.recorded_by = professor }
          students.map { |student| attendance_row(session, student, week, index, professor) }
        end
        AttendanceRecord.insert_all(rows, unique_by: :index_attendance_records_on_session_and_student) if rows.any?
      end
    end

    # One class a week, on a weekday that depends on the section, up to today or the end of the term.
    # The week of Fiestas Patrias has no classes.
    def class_dates(section, index)
      term = section.term_id == @past_term.id ? @past_term : @current_term
      first_monday = term.starts_on + ((1 - term.starts_on.wday) % 7) + 7
      last_day = [ @today, term.ends_on ].min

      (0..25).filter_map do |week|
        held_on = first_monday + week * 7 + index % 5
        next if held_on > last_day || held_on.cweek == Date.new(2026, 9, 18).cweek

        held_on
      end
    end

    # Each student misses between 5 % and 30 % of the classes. Some marks were corrected afterwards (B7).
    def attendance_row(session, student, week, section_index, professor)
      number = number_of(student)
      absent = (number * 31 + week * 17 + section_index * 7) % 100 < 5 + (number % 6) * 5
      corrected = (number + week + section_index) % 37 == 0

      {
        attendance_session_id: session.id, student_id: student.id, university_id: @university.id,
        status: absent && !corrected ? "ausente" : "presente",
        corrected_by_id: corrected ? professor.id : nil,
        corrected_at: corrected ? (session.held_on + 1).to_time.change(hour: 10) : nil
      }
    end

    # Announcements, material and notifications ----------------------------------------------------------------

    def build_announcements
      @current_sections.group_by(&:course).each do |course, sections|
        coordinator = CourseCoordinator.find_by(course: course, term: @current_term)&.user
        next unless coordinator

        announce(course, nil, coordinator, Date.new(2026, 8, 3), "Bienvenida a #{course.name}",
                 "Les damos la bienvenida al curso. El programa y el calendario de evaluaciones están en Material.")
        announce(course, nil, coordinator, Date.new(2026, 8, 17), "Calendario de evaluaciones",
                 "Controles cada cuatro semanas, dos tareas y dos pruebas. El examen es el 7 de diciembre.")
        announce(course, nil, coordinator, Date.new(2026, 11, 2), "Inscripción para el examen",
                 "Revisen en Mis notas si cumplen los requisitos para rendir el examen.")

        sections.each do |section|
          professor = professor_of(section)
          next unless professor

          label = "Sección #{section.number}"
          announce(course, section, professor, Date.new(2026, 8, 31), "#{label}: cambio de sala",
                   "Desde esta semana las clases de la #{label.downcase} son en la sala B-#{200 + section.number * 10 + course_index(section)}.")
          announce(course, section, professor, Date.new(2026, 9, 21), "#{label}: recordatorio de la Prueba 1",
                   "La Prueba 1 es el lunes 28 de septiembre. Incluye las unidades 1 y 2.")
          announce(course, section, professor, Date.new(2026, 10, 19), "#{label}: notas de la Prueba 1 publicadas",
                   "Ya pueden revisar su nota y la retroalimentación en Mis notas.")
        end
      end
    end

    def announce(course, section, author, date, subject, body)
      return if date > @today

      Announcement.find_or_create_by!(course: course, section: section, subject: subject) do |announcement|
        announcement.author = author
        announcement.body = body
        announcement.created_at = announcement.updated_at = date.to_time.change(hour: 9)
      end
    end

    # B1: material as .txt files with a single character, since only the listing, preview and download matter.
    # Empty files are not allowed (Material rejects 0 bytes).
    def build_materials
      @courses.each_value do |course|
        author = CourseCoordinator.find_by(course: course, term: @current_term)&.user
        next unless author

        count = 3 + course_index_for(course) % 4
        DemoVolumeSeeds::MATERIALS.first(count).each do |title|
          Material.find_or_create_by!(course: course, title: title) do |material|
            material.uploaded_by = author
            material.file.attach(
              io: StringIO.new(("a".."z").to_a.sample), filename: "#{title.parameterize}.txt", content_type: "text/plain",
              # Already analyzed: the seeds do not depend on Sidekiq or Redis to finish.
              metadata: { identified: true, analyzed: true }
            )
          end
        end
      end
    end

    def course_index_for(course) = @course_codes.index(course.code)

    # C5/C6/C12: what the grade jobs would have sent, with the same wording. Older notices are already read.
    def build_notifications
      Evaluation.where(section: @current_sections.reject { |section| demo?(section) }).includes(section: :course).find_each do |evaluation|
        grades = Grade.where(evaluation: evaluation)
        next if grades.none?

        title = evaluation.title_with_section
        published = grades.publicada.pluck(:student_id)
        pending = grades.pendiente.count
        rejected = grades.rechazada

        notify(published, "nota_publicada", "Tu nota de #{title} ya está publicada.", evaluation.due_on + DemoVolumeSeeds::PUBLISHED_AFTER,
               read: evaluation.due_on + DemoVolumeSeeds::PUBLISHED_AFTER + 7 <= @today)

        if pending.positive?
          professor = professor_of(evaluation.section)
          message = pending == 1 ? "1 nota de #{title} espera tu revisión." : "#{pending} notas de #{title} esperan tu revisión."
          notify([ professor&.id ].compact, "notas_en_revision", message, evaluation.due_on + 2, read: false)
        end

        if rejected.exists?
          count = rejected.count
          amount = count == 1 ? "1 nota" : "#{count} notas"
          message = "El profesor rechazó #{amount} de #{title}: «#{rejected.first.rejection_comment}»"
          notify(rejected.distinct.pluck(:entered_by_id), "notas_rechazadas", message, evaluation.due_on + 5, read: false)
        end
      end
    end

    def notify(recipient_ids, kind, message, date, read:)
      return if recipient_ids.empty? || Notification.exists?(kind: kind, message: message)

      time = date.to_time.change(hour: 18)
      rows = recipient_ids.map do |recipient_id|
        { recipient_id: recipient_id, university_id: @university.id, kind: kind, message: message,
          read_at: read ? time + 1.day : nil, created_at: time, updated_at: time }
      end
      Notification.insert_all(rows)
    end
  end
end
