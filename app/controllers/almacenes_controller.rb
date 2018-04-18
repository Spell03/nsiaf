class AlmacenesController < ApplicationController
  def index
    authorize! :indice, :almacenes
  end
end
