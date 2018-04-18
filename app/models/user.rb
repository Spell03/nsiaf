class User < ActiveRecord::Base
  include ImportDbf, Migrated, VersionLog, ManageStatus

  CORRELATIONS = {
    'CODRESP' => 'code',
    'NOMRESP' => 'name',
    'CARGO' => 'title',
    'API_ESTADO' => 'status'
  }

  ROLES = %w[admin admin_store]

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  belongs_to :department
  has_many :assets
  has_many :bajas
  has_many :proceedings, foreign_key: :user_id
  has_many :ingresos

  scope :actives, -> { where(status: '1') }

  with_options if: :is_not_migrate? do |m|
    m.validates :email, presence: false, allow_blank: true
    m.validates :code, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    m.validates :name, :title, presence: true
    m.validates :username, presence: true, length: {minimum: 4, maximum: 128}, uniqueness: true
    m.validates :phone, :mobile, numericality: { only_integer: true }, allow_blank: true
    m.validates :department_id, presence: true
  end

  with_options if: :is_migrate? do |m|
    m.validates :code, presence: true, uniqueness: { scope: :department_id }, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    m.validates :department_id, presence: true
  end

  with_options if: :is_admin_or_super? do |m|
    m.validates :name, presence: true
    m.validates :username, presence: true, length: {minimum: 4, maximum: 128}, uniqueness: true
    m.validates :role, presence: true, format: { with: /#{ROLES.join('|')}/ }
  end

  before_validation :set_defaults

  has_paper_trail ignore: [:last_sign_in_at, :current_sign_in_at, :last_sign_in_ip, :current_sign_in_ip, :sign_in_count, :updated_at, :status, :password_change, :encrypted_password]

  def active_for_authentication?
    super && self.status == '1'
  end

  def change_password(user_params)
    transaction do
      update_with_password(user_params) &&
        hide_announcement &&
        register_log(:password_changed)
    end
  end

  def inactive_message
    I18n.t('unauthorized.manage.user_inactive')
  end

  def department_entity_acronym
    department.present? ? department.entity_acronym : ''
  end

  def department_code
    department.present? ? department.code : ''
  end

  def department_name
    department.present? ? department.name : ''
  end

  def depto_code
    "#{department_code}#{code}"
  end

  def depto_name
    "#{department_name} - #{name}"
  end

  def email_required?
    false
  end

  def entity_name
    department.present? ? department.entity_name : ''
  end

  # Obtiene la imagen para los encabezados y pie para un documento
  def get_image(tipo)
    tipo == 'header' ? get_image_header : get_image_footer
  end

  # Obtiene la imagen para el pie de página de los documentos
  def get_image_footer
    department.present? ? department.get_image_footer : ''
  end

  # Obtiene la imagen para el encabezado de los documentos
  def get_image_header
    department.present? ? department.get_image_header : ''
  end

  def has_roles?
    self.role.present?
  end

  def hide_announcement
    update_column(:password_change, true)
  end

  def is_admin?
    self.role == 'admin'
  end

  def is_admin_store?
    self.role == 'admin_store'
  end

  def is_admin_or_super?
    is_super_admin? || is_admin?
  end

  def is_super_admin?
    self.role == 'super_admin'
  end

  def not_assigned_assets
    # TODO Tiene que definirse que activos no están asignados,
    # tambien se debe tomar en cuenta las auto-asignaciones del admin
    assets
  end

  def password_changed?
    password_change == true
  end

  def users
    User.where('role IS NULL OR role != ?', 'super_admin')
  end

  def self.search_by(department_id)
    users = []
    users = where(department_id: department_id) if department_id.present?
    [['', '--']] + users.map { |u| [u.id, u.name] }
  end

  def self.set_columns(cu = nil)
    h = ApplicationController.helpers
    if cu
      [h.get_column(self, 'name'), h.get_column(self, 'role')]
    else
      [h.get_column(self, 'code'), h.get_column(self, 'ci'), h.get_column(self, 'name'), h.get_column(self, 'title'), h.get_column(self, 'department')]
    end
  end

  def verify_assignment
    assets.present?
  end

  def self.array_model(sort_column, sort_direction, page, per_page, sSearch, search_column, current_user)
    array = current_user.users.includes(:department).order("#{sort_column} #{sort_direction}").references(:department)
    array = array.page(page).per_page(per_page) if per_page.present?
    if sSearch.present?
      if search_column.present?
        type_search = search_column == 'department' ? 'departments.name' : "users.#{search_column}"
        array = array.where("#{type_search} like :search", search: "%#{sSearch}%")
      else
        if current_user.is_super_admin?
          array = array.where("users.name LIKE ? OR users.role LIKE ?", "%#{sSearch}%", "%#{sSearch}%")
        else
          array = array.where("users.code LIKE ? OR users.ci LIKE ? OR users.name LIKE ? OR users.title LIKE ? OR departments.name LIKE ?", "%#{sSearch}%", "%#{sSearch}%", "%#{sSearch}%", "%#{sSearch}%", "%#{sSearch}%")
        end
      end
    end
    array
  end

  def self.to_csv
    columns = %w(ci name title department status)
    h = ApplicationController.helpers
    CSV.generate do |csv|
      csv << columns.map { |c| self.human_attribute_name(c) }
      all.each do |user|
        a = user.attributes.values_at(*columns)
        a.pop(2)
        a.push(user.department_name, h.type_status(user.status))
        csv << a
      end
    end
  end

  def self.search_user(q)
    h = ApplicationController.helpers
    h.status_active(self).where("name LIKE ? AND username != ?", "%#{q}%", 'admin').map{ |s| { id: s.id, name: s.name, title: s.title } }
  end

  private

  ##
  # Guarda en la base de datos de acuerdo a la correspondencia de campos.
  def self.save_correlations(record)
    user = { is_migrate: true, password: 'Demo1234' }
    CORRELATIONS.each do |origin, destination|
      user.merge!({ destination => record[origin] })
    end
    d = Department.find_by_code(record['CODOFIC'])
    d.present? && user.present? && new(user.merge!({ department: d })).save
  end

  def set_defaults
    if username_was.blank? && password.nil? && !username.nil?
      self.password ||= self.username
    end
  end
end
