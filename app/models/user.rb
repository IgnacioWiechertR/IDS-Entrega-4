class User < ApplicationRecord
  # Agregamos :lockable a la configuración que ya tenías
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :lockable

  # Definición de roles (según tu diagrama C4)
  enum :role, { director: 0, administrativo: 1, profesor: 2, ayudante: 3, alumno: 4 }

  # Validaciones de datos mínimos requeridos
  validates :name, :rut, :role, presence: true
  validate :validar_rut_chileno
  validate :validar_rut_unico_por_universidad

  
  belongs_to :university, optional: true
  has_many :user_roles, dependent: :destroy
  has_many :course_coordinators, dependent: :destroy
  has_many :assigned_course_coordinators, class_name: "CourseCoordinator", foreign_key: :assigned_by_id, dependent: :destroy
  has_many :section_staffs, dependent: :destroy
  has_many :assigned_section_staffs, class_name: "SectionStaff", foreign_key: :assigned_by_id, dependent: :destroy
  has_many :enrollments, foreign_key: :student_id, dependent: :destroy
  has_many :grades, foreign_key: :student_id, dependent: :destroy
  has_many :entered_grades, class_name: "Grade", foreign_key: :entered_by_id, dependent: :destroy
  has_many :reviewed_grades, class_name: "Grade", foreign_key: :reviewed_by_id, dependent: :nullify
  has_many :recorded_attendance_sessions, class_name: "AttendanceSession", foreign_key: :recorded_by_id, dependent: :destroy
  has_many :attendance_records, foreign_key: :student_id, dependent: :destroy
  has_many :announcements, foreign_key: :author_id, dependent: :destroy
  has_many :notifications, foreign_key: :recipient_id, dependent: :destroy

  # Asigna rol por defecto antes de validar la creación de la cuenta
  before_validation :set_default_role, on: :create

  private

  # Método para asignar el rol por defecto si no viene uno
  def set_default_role
    self.role ||= :alumno
  end

  # Método de validación del RUT
  def validar_rut_chileno
    return if rut.blank?
    unless rut.match?(/\A\d{7,8}-[Kk\d]\z/)
      errors.add(:rut, "no tiene un formato válido. Ej: 12345678-9")
    end
  end

  # Método para garantizar unicidad por sede e indicar la cuenta existente
  def validar_rut_unico_por_universidad
    return if rut.blank? || university_id.blank?

    # Busca si existe otro usuario con el mismo RUT en la misma universidad
    usuario_existente = User.where(rut: rut, university_id: university_id).where.not(id: id).first
    
    if usuario_existente
      errors.add(:rut, "ya está registrado en esta sede a nombre de #{usuario_existente.name}")
    end
  end
end