class Account < ActiveRecord::Base
  include ImportDbf, VersionLog
  include Moneda

  CORRELATIONS = {
    'CODCONT' => 'code',
    'NOMBRE' => 'name',
    'VIDAUTIL' => 'vida_util',
    'DEPRECIAR' => 'depreciar',
    'ACTUALIZAR' => 'actualizar'
  }

  validates :code, presence: true, uniqueness: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :name, presence: true

  has_many :auxiliaries
  has_many :assets

  has_paper_trail

  # Lista de activos de una cuenta
  def self.activos
    Asset.joins(auxiliary: :account)
         .where(accounts: {id: ids})
         .uniq
  end

  def self.set_columns
    h = ApplicationController.helpers
    [h.get_column(self, 'code'), h.get_column(self, 'name')]
  end

  def self.array_model(sort_column, sort_direction, page, per_page, sSearch, search_column, current_user = '')
    array = order("#{sort_column} #{sort_direction}")
    array = array.page(page).per_page(per_page) if per_page.present?
    if sSearch.present?
      if search_column.present?
        array = array.where("#{search_column} like :search", search: "%#{sSearch}%")
      else
        array = array.where("code LIKE ? OR name LIKE ? OR vida_util LIKE ?", "%#{sSearch}%", "%#{sSearch}%", "%#{sSearch}%")
      end
    end
    array
  end

  def self.to_csv
    columns = %w(code name vida_util)
    CSV.generate do |csv|
      csv << columns.map { |c| self.human_attribute_name(c) }
      all.each do |account|
        csv << account.attributes.values_at(*columns)
      end
    end
  end

  def self.con_activos
    joins(auxiliaries: :assets).uniq
  end

  def code_and_name
    "#{code} - #{name}"
  end

  ##
  # BEGIN datos para el reporte resumen de activos fijos ordenado por grupo contable
  def auxiliares_activos(desde = Date.today, hasta = Date.today)
    activos_bajas_ids = Asset.bajas.where(bajas: {fecha: desde..hasta}).ids
    Asset.joins(:ingreso)
         .where(auxiliary_id: auxiliaries.ids)
         .where(ingresos: {factura_fecha: desde..hasta})
         .where.not(id: activos_bajas_ids)
  end

  # Lista de activos dados de baja en la cuenta en un rango de fechas
  def auxiliares_activos_bajas(desde = Date.today, hasta = Date.today)
    Asset.joins(:baja)
         .where(auxiliary_id: auxiliaries.ids)
         .where(bajas: {fecha: desde..hasta})
  end

  def cantidad_activos(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).length
  end

  def costo_historico(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).costo_historico
  end

  def costo_actualizado_inicial(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).costo_actualizado_inicial(hasta)
  end

  def depreciacion_acumulada_inicial(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).depreciacion_acumulada_inicial(hasta)
  end

  def valor_neto_inicial(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).inject(0) do |suma, activo|
      suma + activo.costo_actualizado_inicial(hasta) - activo.depreciacion_acumulada_inicial(hasta)
    end
  end

  def actualizacion_gestion(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).actualizacion_gestion(hasta)
  end

  def costo_actualizado(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).costo_actualizado(hasta)
  end

  def depreciacion_gestion(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).depreciacion_gestion(hasta)
  end

  def actualizacion_depreciacion_acumulada(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).actualizacion_depreciacion_acumulada(hasta)
  end

  def depreciacion_acumulada_total(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).depreciacion_acumulada_total(hasta)
  end

  def valor_neto(desde = Date.today, hasta = Date.today)
    auxiliares_activos(desde, hasta).valor_neto(hasta)
  end

  def self.cantidad_activos(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + cuenta.cantidad_activos(desde, hasta)
    end
  end

  def self.costo_historico(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.costo_historico(desde, hasta))
    end
  end

  def self.costo_actualizado_inicial(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.costo_actualizado_inicial(desde, hasta))
    end
  end

  def self.depreciacion_acumulada_inicial(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.depreciacion_acumulada_inicial(desde, hasta))
    end
  end

  def self.valor_neto_inicial(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.valor_neto_inicial(desde, hasta))
    end
  end

  def self.actualizacion_gestion(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.actualizacion_gestion(desde, hasta))
    end
  end

  def self.costo_actualizado(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.costo_actualizado(desde, hasta))
    end
  end

  def self.depreciacion_gestion(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.depreciacion_gestion(desde, hasta))
    end
  end

  def self.actualizacion_depreciacion_acumulada(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.actualizacion_depreciacion_acumulada(desde, hasta))
    end
  end

  def self.depreciacion_acumulada_total(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.depreciacion_acumulada_total(desde, hasta))
    end
  end

  def self.valor_neto(desde = Date.today, hasta = Date.today)
    all.inject(0) do |suma, cuenta|
      suma + redondear(cuenta.valor_neto(desde, hasta))
    end
  end
  # END datos para el reporte resumen de activos fijos ordenado por grupo contable
  ##
  #
  ##

  def retorna_auxiliares
    auxiliaries.select('auxiliaries.id,auxiliaries.code, auxiliaries.name, count(assets.id) as cantidad_activos , sum(assets.precio) as monto_activos')
               .joins(:assets)
               .group('auxiliaries.id')
               .order('auxiliaries.code')

  end

  def retorna_activos
    auxiliaries.select('assets.id, assets.code, assets.description, auxiliaries.name, assets.precio')
               .joins(:assets)
               .order('assets.code')
  end
end
