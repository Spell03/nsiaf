$ -> new NoteEntry() if $('[data-action=note_entry]').length > 0

class NoteEntry extends BarcodeReader
  cacheElements: ->
    @$note_entry_urls = $('#note_entry-urls')
    @$obt_note_entry_urls = $('#obt_note_entry-urls')
    @obt_note_entry_url = @$obt_note_entry_urls.data('obt-note-entry')
    @id_note_entry = @$obt_note_entry_urls.data('noteEntry')
    @$inputSupplier = $('input#note_entry_supplier_id')
    @formNoteEntry = $('#new_note_entry')
    @editFormNoteEntry = $('.edit_note_entry')
    @btnSaveNoteEntry = $('#save_note_entry .btn-primary')
    @btnEditSaveNoteEntry = $('#edit_save_note_entry .btn-primary')
    @$subarticles = $('#subarticles')
    @$subtotalSuma = @$subarticles.find('.subtotal-suma')
    @$descuento = @$subarticles.find('.descuento')
    @$totalSuma = @$subarticles.find('.total-suma')
    @$inputTotal = $('#note_entry_total')
    @$inputSubtotal = $('#note_entry_subtotal')
    @$inputObservacion = $('#note_entry_observacion')

    @alert = new Notices({ele: 'div.main'})
    # Contenedores
    @$confirmModal = $('#confirm-modal')
    @$confirmarNotaIngresoModal = $('#modal-confirmar-nota-ingreso')
    @$alertaNotaIngresoModal = $('#modal-alerta-nota-ingreso')

    # Plantillas
    @$confirmarNotaIngresoTpl = Hogan.compile $('#confirmar-nota-ingreso-tpl').html() || ''
    @$alertaNotaIngresoTpl = Hogan.compile $('#alerta-nota-ingreso-tpl').html() || ''

  bindEvents: ->
    if @$inputSupplier?
      @get_suppliers()
    $(document).on 'click', @btnSaveNoteEntry.selector, (e) => @get_note_entry(e)
    $(document).on 'click', @btnEditSaveNoteEntry.selector, (e) => @confirmarNotaIngreso(e)
    $(document).on 'keyup', '.amount, .unit_cost, .descuento', (e) => @actualizarTotales(e)
    $(document).on 'click', @$confirmarNotaIngresoModal.find('button[type=submit]').selector, (e) => @validarObservacion(e)
    $(document).on 'click', @$alertaNotaIngresoModal.find('button[type=submit]').selector, (e) => @aceptarAlertaNotaIngreso(e)

  confirmarNotaIngreso: (e) ->
    e.preventDefault()
    if @id_note_entry
      url = @obt_note_entry_url + "?d=" + $("#note_entry_invoice_date").val() + '&n=' + @id_note_entry
    else
      url = @obt_note_entry_url + "?d=" + $("#note_entry_invoice_date").val()
    $.ajax
      url: url
      type: 'GET'
      dataType: 'JSON'
    .done (xhr) =>
      data = xhr
      if data["tipo_respuesta"]
        if data["tipo_respuesta"] == "confirmacion"
          @$confirmModal.html @$confirmarNotaIngresoTpl.render(data)
          modal = @$confirmModal.find(@$confirmarNotaIngresoModal.selector)
          modal.modal('show')
        else if data["tipo_respuesta"] == "alerta"
          @$confirmModal.html @$alertaNotaIngresoTpl.render(data)
          modal = @$confirmModal.find(@$alertaNotaIngresoModal.selector)
          modal.modal('show')
      else
        if @formNoteEntry.length > 0
          $.post @formNoteEntry.attr('action'), @formNoteEntry.serialize(), null, 'script'
        else if @editFormNoteEntry.length > 0
          $.post @editFormNoteEntry.attr('action'), @editFormNoteEntry.serialize(), null, 'script'

  aceptarConfirmarNotaIngreso: (e) ->
    e.preventDefault()
    el = @$confirmModal.find('#modal_observacion')
    if el
      @$inputObservacion.val(el.val())
    @$confirmModal.find(@$confirmarNotaIngresoModal.selector).modal('hide')
    $form = $(e.target).closest('form')
    if @formNoteEntry.length > 0
      $.post @formNoteEntry.attr('action'), @formNoteEntry.serialize(), null, 'script'
    else if @editFormNoteEntry.length > 0
      $.post @editFormNoteEntry.attr('action'), @editFormNoteEntry.serialize(), null, 'script'
    else
      false

  validarObservacion: (e) ->
    el = @$confirmModal.find('#modal_observacion')
    if el
      valor = $.trim(el.val())
      if valor
        el.parents('.form-group').removeClass('has-error')
        el.next().remove()
        @aceptarConfirmarNotaIngreso(e)
      else
        el.parents('.form-group').addClass('has-error')
        el.after('<span class="help-block">no puede estar en blanco</span>') unless $('span.help-block').length
        false

  aceptarAlertaNotaIngreso: (e) ->
    e.preventDefault()
    @$confirmModal.find(@$alertaNotaIngresoModal.selector).modal('hide')
    $form = $(e.target).closest('form')
    false

  actualizarTotales: (e) ->
    @mostrarTotalParcial($(e.target))
    @mostrarSubtotal()
    @mostrarTotal()

  get_suppliers: ->
    bestPictures = new Bloodhound(
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace("description")
      queryTokenizer: Bloodhound.tokenizers.whitespace
      limit: 100
      remote: decodeURIComponent @$note_entry_urls.data('get-suppliers')
    )
    bestPictures.initialize()
    @$inputSupplier.typeahead null,
      displayKey: "name"
      source: bestPictures.ttAdapter()

  get_note_entry: (e)->
    if @$inputSupplier.val()
      @$inputSupplier.parents('.form-group').removeClass('has-error')
      @$inputSupplier.next().remove()
      @valid = true
    else
      @$inputSupplier.parents('.form-group').addClass('has-error')
      @$inputSupplier.after('<span class="help-block">no puede estar en blanco</span>') unless $('span.help-block').length
      @valid = false

    if @$subarticles.find('tr.subarticle').length
      size = @$subarticles.find('tr.subarticle').length
      @$subarticles.find('tr.subarticle').each (i, el) =>
        if $.isNumeric($(el).find('.amount').val()) && $.isNumeric($(el).find('.unit_cost').val())
          $(el).removeClass('danger')
          $(el).find('input').attr('style', '')
          @valid = true
          @confirmarNotaIngreso(e) if @valid && i == (size - 1)
        else
          $(el).addClass('danger')
          $(el).find('input').css('background-color', '#f2dede')
          new Notices({ele: 'div.main'}).danger "Verifique los campos a llenar del material '#{$(el).find('.description').text()}'"
          @valid = false
    else
      @open_modal 'Debe añadir al menos un material'
      @valid = false

  open_modal: (content) ->
    @alert.danger content

  mostrarSubtotal: ->
    sumaSubtotal = @sumarSubtotal()
    @$subtotalSuma.text sumaSubtotal.formatNumber(2, '.', ',')
    @$inputSubtotal.val(sumaSubtotal)

  mostrarTotal: ->
    sumaTotal = @sumarTotal()
    @$totalSuma.text sumaTotal.formatNumber(2, '.', ',')
    @$inputTotal.val(sumaTotal) # establecer el total

  mostrarTotalParcial: ($elem) ->
    $fila = $elem.closest('tr')
    totalParcial = @totalParcial($fila)
    $fila.find('.total-parcial').text totalParcial.formatNumber(2, '.', ',')
    $fila.find('input.total-cost').val totalParcial # establecer total parcial

  descuento: ->
    if $.isNumeric(@$descuento.val())
      parseFloat @$descuento.val()
    else
      0

  sumarSubtotal: ->
    @$subarticles.find('tr.subarticle').toArray().reduce (suma, fila) =>
      suma + @totalParcial($(fila))
    , 0

  sumarTotal: ->
    @sumarSubtotal() - @descuento()

  totalParcial: ($fila) ->
    amount = parseFloat($fila.find('input.amount').val()) || 0
    unit_cost = parseFloat($fila.find('input.unit_cost').val()) || 0
    amount * unit_cost
