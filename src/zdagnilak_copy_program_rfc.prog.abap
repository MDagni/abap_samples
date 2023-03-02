************************************************************************
* Developer        : Mehmet Dağnilak
* Description      : Programı RFC aracılığıyla kopyala
************************************************************************
* History
*----------------------------------------------------------------------*
* User-ID     Date      Description
*----------------------------------------------------------------------*
* MDAGNILAK   20200722  Program created
* <userid>    yyyymmdd  <short description of the change>
************************************************************************

report zdagnilak_copy_program_rfc.

tables: sscrfields.

selection-screen begin of block b1 with frame.
parameters: program  radiobutton group prg,
            p_prog   type syrepid memory id zcopy_name,
            p_witext as checkbox.
selection-screen skip.
parameters: function radiobutton group prg,
            p_func   type tfdir-funcname memory id zcopy_func.
selection-screen skip.
parameters: method   radiobutton group prg,
            p_class  type seoclsname memory id zcopy_class,
            p_method type seocpdname memory id zcopy_method.
selection-screen skip.
parameters: struct  radiobutton group prg,
            p_struc type tabname memory id zcopy_struc.
selection-screen end of block b1.

selection-screen begin of block b2 with frame.
parameters: p_destin type rfcdest obligatory memory id vers_dest,
            p_debug  as checkbox.
selection-screen end of block b2.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN
*&---------------------------------------------------------------------*
at selection-screen.

  "RFC hedefinin yalnızca bir kere şifre sorması için çalıştırma burada yapıldı.
  if sscrfields-ucomm eq 'ONLI'.
    perform main.
    clear sscrfields-ucomm.
  endif.

start-of-selection.
  "nothing

*&---------------------------------------------------------------------*
*&      Form  main
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form main.

  data: lo_reader      type ref to if_siw_repository_reader,
        lt_code        type siw_tab_code,
        lt_textpool    type textpool_table,
        lv_incname     type syrepid,
        lv_description type repti,
        ls_exception   type siw_str_msg,
        lv_msg         type text255.

  lo_reader = cl_siw_resource_access=>s_get_instance( ).

  try.

      case abap_true.
        when program.
          data(ls_trdir) = lo_reader->read_trdir( p_prog ).
          if ls_trdir is initial.
            message 'Program mevcut değil' type 'I'.
            return.
          endif.

          lv_incname = p_prog.
          lt_code = lo_reader->read_report( p_prog ).

          if ls_trdir-subc ca '1MFS'.
            data(lt_textall) = lo_reader->read_textpool( i_prog      = p_prog
                                                         i_tab_langu = value #( ( spras = sy-langu ) ) ).

            lt_textpool = value #( lt_textall[ 1 ]-texts optional ).
            lv_description = value #( lt_textpool[ id = 'R' ]-entry optional ).

            if p_witext is initial.
              refresh lt_textpool.
            endif.
          endif.

        when function.
          data(ls_funcinfo) = lo_reader->read_funcinfo( p_func ).
          lv_incname = ls_funcinfo-include.
          ls_trdir-subc = 'I'.
          lt_code = lo_reader->read_report( lv_incname ).

          loop at lt_code assigning field-symbol(<ls_code>) from 2.
            if <ls_code>(2) ne '*"'.
              exit.
            endif.
            delete lt_code.
          endloop.

        when method.
          lo_reader->read_method_source(
            exporting
              i_clsname    = p_class
              i_methodname = p_method
            importing
              e_tab_code   = lt_code
              e_incname    = lv_incname ).

        when struct.
          lo_reader->read_stru(
            exporting
              i_name           = p_struc
              i_langu          = sy-langu
            importing
              e_str_stru       = data(ls_str_stru)
              e_tab_stru_field = data(lt_stru_field) ).

          lv_incname = p_struc.

      endcase.

    catch cx_siw_resource_failure into data(lx_rf).
      message lx_rf type 'I' display like 'E'.
      return.
  endtry.

  call function 'RFC_PING_AND_WAIT'
    destination p_destin
    exceptions
      system_failure        = 1 message lv_msg
      communication_failure = 2 message lv_msg.

  if sy-subrc ne 0 or
     lv_msg is not initial.
    message lv_msg type 'I' display like 'E'.
    return.
  endif.

  if p_debug = abap_true.
    break-point.
  endif.

  case abap_true.
    when program.

      call function 'SIW_RFC_WRITE_REPORT'
        destination p_destin
        exporting
          i_name                = lv_incname
          i_tab_code            = lt_code
          i_extension           = ''
          i_object              = ''
          i_objname             = ''
          i_progtype            = ls_trdir-subc
          i_description         = lv_description
        importing
          e_str_exception       = ls_exception
        exceptions
          system_failure        = 1 message lv_msg
          communication_failure = 2 message lv_msg.

    when function.

      call function 'SIW_RFC_WRITE_FUNC'
        destination p_destin
        exporting
          i_name                = p_func
          i_function_group      = ls_funcinfo-funcpool
          i_tab_code            = lt_code
          i_str_signature       = ls_funcinfo-str_signature
          i_str_attributes      = ls_funcinfo-str_attributes
          i_tab_top_code        = value siw_tab_code( )
          i_flg_delete          = abap_false
        importing
          e_str_exception       = ls_exception
        exceptions
          system_failure        = 1 message lv_msg
          communication_failure = 2 message lv_msg.

    when method.

      call function 'SIW_RFC_WRITE_CLASS_METHOD'
        destination p_destin
        exporting
          i_clsname             = p_class
          i_methodname          = p_method
          i_tab_code            = lt_code
        importing
          e_str_exception       = ls_exception
        exceptions
          system_failure        = 1 message lv_msg
          communication_failure = 2 message lv_msg.

    when struct.

      call function 'SIW_RFC_WRITE_STRU'
        destination p_destin
        exporting
          i_str_stru            = ls_str_stru
          i_tab_stru_field      = lt_stru_field
          i_flg_activate        = abap_true
        importing
          e_str_exception       = ls_exception
        exceptions
          system_failure        = 1 message lv_msg
          communication_failure = 2 message lv_msg.

  endcase.

  if sy-subrc ne 0 or
     lv_msg is not initial.
    message lv_msg type 'I' display like 'E'.
    return.
  endif.

  if ls_exception is not initial.
    message ls_exception-msgstring type 'I' display like 'E'.
    return.
  endif.

  if lt_textpool is not initial.

    call function 'SIW_RFC_WRITE_TEXTPOOL'
      destination p_destin
      exporting
        i_prog                = lv_incname
        i_langu               = sy-langu
        i_tab_textpool        = lt_textpool
      importing
        e_str_exception       = ls_exception
      exceptions
        system_failure        = 1 message lv_msg
        communication_failure = 2 message lv_msg.

    if sy-subrc ne 0 or
       lv_msg is not initial.
      message lv_msg type 'I' display like 'E'.
      return.
    endif.

    if ls_exception is not initial.
      message ls_exception-msgstring type 'I' display like 'E'.
      return.
    endif.

  endif.

  message |{ lv_incname } kopyalandı| type 'S'.

endform.          " main
