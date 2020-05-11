report zsalv_grid_events.

class lcl_grid_trick definition
  final
  create public .

  public section.
    interfaces if_alv_rm_grid_friend . "important

    data: mt_spfli type standard table of spfli,
          mo_salv  type ref to cl_salv_table.

    methods:
      create_salv.
    methods:
      evh_after_refresh for event after_refresh of cl_gui_alv_grid importing sender,
      evh_del_change_selection for event delayed_changed_sel_callback of cl_gui_alv_grid.
  private section.
    data: mv_handler_added type abap_bool.
endclass.

class lcl_grid_trick implementation.
  method create_salv.
    select * up to 100 rows into corresponding fields of table @mt_spfli
    from spfli.

    cl_salv_table=>factory(
      importing
        r_salv_table   = mo_salv
      changing
        t_table        = mt_spfli
    ).

    "Setting handler for event after_refresh for all grids
    set handler evh_after_refresh for all instances.

    "just to triger handler
    mo_salv->refresh( ).


    data(selections) = mo_salv->get_selections( ).
    selections->set_selection_mode(   if_salv_c_selection_mode=>cell  ). "Single row selection


    mo_salv->display( ).

  endmethod.

  method evh_after_refresh.

    check mv_handler_added eq abap_false.

    set handler me->evh_del_change_selection for sender.

*    "to use this method you need to inherit from cl_gui_alv_grid or add interface IF_ALV_RM_GRID_FRIEND
*    "to your class
    sender->set_delay_change_selection(
      exporting
        time   =  100    " Time in Milliseconds
      exceptions
        error  = 1
        others = 2
    ).
    if sy-subrc <> 0.
*     message id sy-msgid type sy-msgty number sy-msgno
*                with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    endif.

    sender->register_delayed_event(
      exporting
        i_event_id =  sender->mc_evt_delayed_change_select
      exceptions
        error      = 1
        others     = 2
    ).
    if sy-subrc <> 0.
    endif.

    sender->get_frontend_fieldcatalog(
      importing
        et_fieldcatalog = data(fcat)    " Field Catalog
    ).

    "setting editable fields
    assign fcat[ fieldname = 'CARRID' ] to field-symbol(<fcat>).
    if sy-subrc eq 0.
      <fcat>-edit = abap_true.
    endif.

    assign fcat[ fieldname = 'CITYFROM' ] to <fcat>.
    if sy-subrc eq 0.
      <fcat>-edit = abap_true.
    endif.

    sender->set_frontend_fieldcatalog( it_fieldcatalog = fcat ).
    sender->register_edit_event(
      exporting
        i_event_id = sender->mc_evt_modified    " Event ID
*      exceptions
*        error      = 1
*        others     = 2
    ).
    if sy-subrc <> 0.
*     message id sy-msgid type sy-msgty number sy-msgno
*                with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    endif.

    sender->set_ready_for_input(
        i_ready_for_input = 1
    ).

    mv_handler_added = abap_true.
    sender->refresh_table_display(
*      exporting
*        is_stable      =     " With Stable Rows/Columns
*        i_soft_refresh =     " Without Sort, Filter, etc.
*      exceptions
*        finished       = 1
*        others         = 2
    ).
    if sy-subrc <> 0.
*     message id sy-msgid type sy-msgty number sy-msgno
*                with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    endif.


  endmethod.

  method evh_del_change_selection.
    message i001(00) with 'Yupi'.
  endmethod.

endclass.

start-of-selection.

  data(output) = new lcl_grid_trick( ).
  output->create_salv( ).
