class AccountSerializer < ActiveModel::Serializer
  self.root = false
  attributes  :id, :codigo, :nombre, :vida_util, :depreciar, :actualizar

  def codigo
    object.code
  end

  def nombre
    object.name
  end

  def depreciar
    object.depreciar == true ? 'Si' : 'No'
  end

  def actualizar
    object.actualizar == true ? 'Si' : 'No'
  end
end
