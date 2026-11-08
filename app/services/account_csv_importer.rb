require "csv"

class AccountCsvImporter
  class InvalidFile < StandardError; end

  MAX_BYTES = 1.megabyte
  REQUIRED_HEADERS = %w[nombre rut correo].freeze
  ALLOWED_HEADERS = %w[nombre rut correo rol].freeze
  Result = Struct.new(:created, :errors, keyword_init: true)

  def initialize(actor:)
    @actor = actor
  end

  def call(file)
    unless @actor.administrativo? && @actor.university_id.present?
      raise CanCan::AccessDenied, "No tienes permiso para importar cuentas."
    end
    raise InvalidFile, "Selecciona un archivo CSV." unless file.respond_to?(:read)

    content = file.read(MAX_BYTES + 1).to_s.dup
    raise InvalidFile, "El archivo no puede superar 1 MB." if content.bytesize > MAX_BYTES
    content.force_encoding(Encoding::UTF_8)
    raise InvalidFile, "Guarda el CSV con codificación UTF-8." unless content.valid_encoding?

    table = CSV.parse(content.delete_prefix("\uFEFF"), headers: true, skip_blanks: false)
    headers = table.headers
    unless headers.present? && headers.uniq == headers &&
        (REQUIRED_HEADERS - headers).empty? && (headers - ALLOWED_HEADERS).empty?
      raise InvalidFile, "Usa las columnas nombre,rut,correo y, opcionalmente, rol."
    end
    raise InvalidFile, "El archivo no contiene cuentas." unless table.any? { |row| row.fields.any?(&:present?) }

    result = Result.new(created: [], errors: [])
    User.transaction do
      table.each.with_index(2) do |row, line|
        next if row.fields.all?(&:blank?)
        if row.fields.length != headers.length
          result.errors << { line: line, messages: [ "La cantidad de columnas no coincide con el encabezado." ] }
          next
        end
        import_row(row, line, result)
      end
    end
    result
  rescue CSV::MalformedCSVError
    raise InvalidFile, "El CSV tiene un formato inválido. Revisa sus comillas y separadores."
  end

  private

  def import_row(row, line, result)
    first_name, last_name = row["nombre"].to_s.strip.split(/\s+/, 2)
    role = row["rol"].to_s.strip.downcase.presence || "alumno"
    unless AccountPolicy::CREATABLE_ROLES.include?(role)
      result.errors << { line: line, messages: [ "El rol debe ser alumno, ayudante o profesor." ] }
      return
    end

    password = SecureRandom.alphanumeric(12)
    account = User.new(first_name: first_name, last_name: last_name,
      rut: row["rut"].to_s.strip, email: row["correo"].to_s.strip.downcase,
      role: role, university: @actor.university, active: true, password: password)

    if account.save
      result.created << { account: account, temporary_password: password }
    else
      result.errors << { line: line, messages: account.errors.full_messages }
    end
  end
end
