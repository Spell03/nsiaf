class Material < ActiveRecord::Base
  include ManageStatus

  has_many :subarticles

  validates :code, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :description, presence: true

  has_paper_trail

  def detalle
    "#{code} - #{description}"
  end

  def valorado_ingresos(desde, hasta)
    subarticles.inject(0) do |total, article|
      total + article.valorado_ingresos(desde, hasta)
    end
  end

  def valorado_salidas(desde, hasta)
    subarticles.inject(0) do |total, article|
      total + article.valorado_salidas(desde, hasta)
    end
  end

  def valorado_saldo(desde, hasta)
    subarticles.inject(0) do |total, article|
      total + article.valorado_saldo(desde, hasta)
    end
  end

  def verify_assignment
    subarticles.present?
  end

  def self.set_columns
    h = ApplicationController.helpers
    [h.get_column(self, 'code'), h.get_column(self, 'description')]
  end

  def self.array_model(sort_column, sort_direction, page, per_page, sSearch, search_column, current_user = '')
    array = order("#{sort_column} #{sort_direction}")
    array = array.page(page).per_page(per_page) if per_page.present?
    if sSearch.present?
      if search_column.present?
        array = array.where("#{search_column} like :search", search: "%#{sSearch}%")
      else
        array = array.where("code LIKE ? OR description LIKE ?", "%#{sSearch}%", "%#{sSearch}%")
      end
    end
    array
  end

  def self.to_csv
    columns = %w(code description status)
    h = ApplicationController.helpers
    CSV.generate do |csv|
      csv << columns.map { |c| self.human_attribute_name(c) }
      all.each do |product|
        a = product.attributes.values_at(*columns)
        a.pop(1)
        a.push(h.type_status(product.status))
        csv << a
      end
    end
  end
end
