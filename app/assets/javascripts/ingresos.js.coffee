$ -> new Ingresos() if $('[data-action=ingresos]').length > 0

class Ingresos
  # lista de activos seleccionados
  _activos = []
  _proveedor = {}
  _factura = {}
  _nota_entrega = {}
  _c31 = {}
  _observacion = {}

  constructor: ->
    @cacheElements()
    @bindEvents()

  cacheElements: ->
    # Contenedor de URLs
    @$ingresosUrls = $('#ingresos-urls')
    # Variables
    @ingresosPath = @$ingresosUrls.data('activos')
    @proveedoresPath = @$ingresosUrls.data('proveedores')
    @$obt_ingreso_urls = $('#obt_ingreso-urls')
    @obt_ingreso_url = @$obt_ingreso_urls.data('obt-ingreso')
    @id_ingreso = @$obt_ingreso_urls.data('ingreso')
    # Elementos
    @$barcode = $('#code')
    @$facturaForm = $('#factura-form')
    @$ingresosForm = $('#ingresos-form')
    @$proveedorAuto = @$facturaForm.find('.proveedor-auto')
    @$ingresosTbl = $('#ingresos-tbl')
    @$proveedorTbl = $('#proveedor-tbl')
    @$buscarBtn = @$ingresosForm.find('button[type=submit]')
    @$guardarBtn = $('.guardar-btn')
    # Campos
    @$proveedorNombre = @$facturaForm.find('#proveedor')
    @$proveedorNit = @$facturaForm.find('#nit')
    @$proveedorTelefono = @$facturaForm.find('#telefono')
    @$facturaNumero = @$facturaForm.find('#factura_numero')
    @$facturaAutorizacion = @$facturaForm.find('#factura_autorizacion')
    @$facturaFecha = @$facturaForm.find('#factura_fecha')
    @$notaEntregaNumero = @$facturaForm.find('#nota_entrega_numero')
    @$notaEntregaFecha = @$facturaForm.find('#nota_entrega_fecha')
    @$c31Numero = @$facturaForm.find('#c31_numero')
    @$c31Fecha = @$facturaForm.find('#c31_fecha')
    @$inputObservacion = $('#observacion')
    # Plantillas
    @$activosTpl = Hogan.compile $('#tpl-activo-seleccionado').html() || ''
    # Growl Notices
    @alert = new Notices({ele: 'div.main'})

    @$confirmModal = $('#confirm-modal')
    @$confirmarIngresoModal = $('#modal-confirmar-ingreso')
    @$alertaIngresoModal = $('#modal-alerta-ingreso')

    # Plantillas
    @$confirmarIngresoTpl = Hogan.compile $('#confirmar-ingreso-tpl').html() || ''
    @$alertaIngresoTpl = Hogan.compile $('#alerta-ingreso-tpl').html() || ''

  bindEvents: ->
    if @$proveedorAuto?
      @proveedorAutocomplete()
    $(document).on 'click', @$buscarBtn.selector, @buscarActivos
    $(document).on 'change', @$proveedorNombre.selector, @capturarProveedor
    $(document).on 'change', @$proveedorNit.selector, @capturarProveedor
    $(document).on 'change', @$proveedorTelefono.selector, @capturarProveedor
    $(document).on 'change', @$facturaNumero.selector, @capturarFactura
    $(document).on 'change', @$facturaAutorizacion.selector, @capturarFactura
    $(document).on 'change', @$facturaFecha.selector, @capturarFactura
    $(document).on 'change', @$notaEntregaNumero.selector, @capturarNotaEntrega
    $(document).on 'change', @$notaEntregaFecha.selector, @capturarNotaEntrega
    $(document).on 'change', @$c31Numero.selector, @capturarC31
    $(document).on 'change', @$c31Fecha.selector, @capturarC31
    $(document).on 'click', @$guardarBtn.selector, @confirmarIngreso
    $(document).on 'click', @$confirmarIngresoModal.find('button[type=submit]').selector, (e) => @validarObservacion(e)
    $(document).on 'click', @$alertaIngresoModal.find('button[type=submit]').selector, (e) => @aceptarAlertaIngreso(e)

  confirmarIngreso: (e) =>
    e.preventDefault()
    if @sonValidosDatos()
      if @id_ingreso
        url = @obt_ingreso_url + "?d=" + $("#factura_fecha").val() + '&n=' + @id_ingreso
      else
        url = @obt_ingreso_url + "?d=" + $("#factura_fecha").val()
      $.ajax
        url: url
        type: 'GET'
        dataType: 'JSON'
      .done (xhr) =>
        data = xhr
        if data["tipo_respuesta"]
          if data["tipo_respuesta"] == "confirmacion"
            @$confirmModal.html @$confirmarIngresoTpl.render(data)
            modal = @$confirmModal.find(@$confirmarIngresoModal.selector)
            modal.modal('show')
          else if data["tipo_respuesta"] == "alerta"
            @$confirmModal.html @$alertaIngresoTpl.render(data)
            modal = @$confirmModal.find(@$alertaIngresoModal.selector)
            modal.modal('show')
        else
          @guardarIngresoActivosFijos(e)
    else
      @alert.danger "Complete todos los datos requeridos"

  aceptarConfirmarIngreso: (e) =>
    e.preventDefault()
    el = @$confirmModal.find('#modal_observacion')
    if el
      @$inputObservacion.val(el.val())
    @capturarObservacion()
    @$confirmModal.find(@$confirmarIngresoModal.selector).modal('hide')
    $form = $(e.target).closest('form')
    @guardarIngresoActivosFijos(e)

  validarObservacion: (e) =>
    el = @$confirmModal.find('#modal_observacion')
    if el
      valor = $.trim(el.val())
      if valor
        el.parents('.form-group').removeClass('has-error')
        el.next().remove()
        @aceptarConfirmarIngreso(e)
      else
        el.parents('.form-group').addClass('has-error')
        el.after('<span class="help-block">no puede estar en blanco</span>') unless $('span.help-block').length
        false

  aceptarAlertaIngreso: (e) ->
    e.preventDefault()
    @$confirmModal.find(@$alertaIngresoModal.selector).modal('hide')
    $form = $(e.target).closest('form')
    false

  adicionarEnLaLista: (data, callback) ->
    _cantidad = 0
    data.forEach (e) =>
      unless @estaEnLaLista(e)
        _cantidad += 1
        _activos.push(e)
    callback(_cantidad > 0)

  buscarActivos: (e) =>
    e.preventDefault()
    _barcode = { barcode: @$barcode.val() }
    $.getJSON @ingresosPath, _barcode, @mostrarActivos
    @$barcode.select()

  capturarC31: =>
    _c31.c31_numero = @$c31Numero.val().trim()
    _c31.c31_fecha = @$c31Fecha.val().trim()

  capturarFactura: =>
    _factura.factura_numero = @$facturaNumero.val().trim()
    _factura.factura_autorizacion = @$facturaAutorizacion.val().trim()
    _factura.factura_fecha = @$facturaFecha.val()

  capturarNotaEntrega: =>
    _nota_entrega.nota_entrega_numero = @$notaEntregaNumero.val().trim()
    _nota_entrega.nota_entrega_fecha = @$notaEntregaFecha.val().trim()

  capturarProveedor: =>
    _proveedor.name = @$proveedorNombre.val().trim()
    _proveedor.nit = @$proveedorNit.val().trim()
    _proveedor.telefono = @$proveedorTelefono.val().trim()

  cargarDatosProveedor: ->
    @$proveedorNit.val _proveedor.nit
    @$proveedorTelefono.val _proveedor.telefono

  capturarObservacion: =>
    _observacion.observacion = @$inputObservacion.val().trim()

  conversionNumeros: ->
    _activos.map (e, i) ->
      e.indice = i + 1
      e.precio_formato = parseFloat(e.precio).formatNumber(2, '.', ',')
      e

  estaEnLaLista: (elemento) ->
    _activos.filter((e) ->
      e.barcode is elemento.barcode
    ).length > 0

  guardarIngresoActivosFijos: (e) =>
    if @sonValidosDatos()
      $(e.target).addClass('disabled')
      $.ajax
        url: @ingresosPath
        type: 'POST'
        dataType: 'JSON'
        data: { ingreso: @jsonIngreso() }
      .done (ingreso) =>
        @alert.success "Se guardó correctamente la Nota de Ingreso"
        window.location = "#{@ingresosPath}/#{ingreso.id}"
      .fail (xhr, status) =>
        @alert.danger 'Error al guardar Nota de Ingreso'
      .always (xhr, status) ->
        $(e.target).removeClass('disabled')
    else
      @alert.danger "Complete todos los datos requeridos"

  jsonIngreso: ->
    ingreso =
      asset_ids: _activos.map((e) -> e.id)
      supplier_id: _proveedor.id
      total: @sumaTotal()
    ingreso = $.extend({}, ingreso, _factura)
    ingreso = $.extend({}, ingreso, _nota_entrega)
    ingreso = $.extend({}, ingreso, _observacion)
    $.extend({}, ingreso, _c31)

  mostrarActivos: (data) =>
    if data.length > 0
      @adicionarEnLaLista data, (sw) =>
        if sw is true
          @mostrarTabla()
    else
      @alert.danger 'No hay resultado para mostrar'

  mostrarTabla: ->
    json =
      activos: @conversionNumeros(_activos)
      cantidad: _activos.length
      total: @sumaTotal().formatNumber(2, '.', ',')
    @$ingresosTbl.html @$activosTpl.render(json)

  proveedorAutocomplete: ->
    proveedores = new Bloodhound(
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace("description")
      queryTokenizer: Bloodhound.tokenizers.whitespace
      limit: 10
      remote: decodeURIComponent(@proveedoresPath)
    )
    proveedores.initialize()
    @$proveedorAuto.typeahead null,
      displayKey: "name"
      source: proveedores.ttAdapter()
    .on 'typeahead:selected', @seleccionarProveedor

  seleccionarProveedor: (evt, proveedor) =>
    _proveedor = proveedor
    @cargarDatosProveedor()

  sonValidosDatos: ->
    _activos.length > 0

  sumaTotal: ->
    _activos.reduce (total, elemento) ->
      total + parseFloat(elemento.precio)
    , 0
