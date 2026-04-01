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

tables sscrfields.

data: begin of so,
        syrepid type syrepid,
      end of so.

selection-screen begin of block b1 with frame.
  parameters program radiobutton group prg.
  select-options s_prog for so-syrepid memory id zcopy_name.
  parameters p_witext as checkbox.

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
*& CLASS LCL_MAIN
*&---------------------------------------------------------------------*
class lcl_main definition create private.

  public section.
    class-methods class_constructor.
    class-methods run.

  private section.

    class-data go_reader type ref to if_siw_repository_reader.

    class-methods copy_program
      importing
        i_program type syrepid.

    class-methods copy_function.
    class-methods copy_method.
    class-methods copy_struct.

endclass.

*&---------------------------------------------------------------------*
*& PROGRAM FLOW
*&---------------------------------------------------------------------*
at selection-screen.

  "RFC hedefinin yalnızca bir kere şifre sorması için çalıştırma burada yapıldı.
  if sscrfields-ucomm = 'ONLI'.
    lcl_main=>run( ).
    clear sscrfields-ucomm.
  endif.

start-of-selection.
  "nothing

*&---------------------------------------------------------------------*
*& CLASS LCL_MAIN
*&---------------------------------------------------------------------*
class lcl_main implementation.

  method class_constructor.

    go_reader = cl_siw_resource_access=>s_get_instance( ).

  endmethod.


  method run.

    data lv_msg type text255.

    call function 'RFC_PING_AND_WAIT'
      destination p_destin
      exceptions
        system_failure        = 1 message lv_msg
        communication_failure = 2 message lv_msg.

    if sy-subrc <> 0 or
       lv_msg   is not initial.
      message lv_msg type 'I' display like 'E'.
      return.
    endif.

    case abap_true.
      when program.
        if s_prog[] is initial.
          return.
        endif.

        select name from trdir
          into table @data(lt_trdir)
          where name in @s_prog
          order by name.

        if sy-subrc <> 0.
          message 'Seçilen programlar mevcut değil' type 'I'.
          return.
        endif.

        clear lv_msg.

        loop at lt_trdir assigning field-symbol(<ls_trdir>).
          copy_program( <ls_trdir>-name ).
          lv_msg = |{ lv_msg },{ <ls_trdir>-name }|.
        endloop.

        message |{ lv_msg+1 } kopyalandı| type 'S'.

      when function.
        copy_function( ).

      when method.
        copy_method( ).

      when struct.
        copy_struct( ).
    endcase.

  endmethod.


  method copy_program.

    data: lt_code        type siw_tab_code,
          lt_textpool    type textpool_table,
          lv_description type repti,
          ls_exception   type siw_str_msg,
          lv_msg         type text255.

    try.

        data(ls_trdir) = go_reader->read_trdir( i_program ).

        lt_code = go_reader->read_report( i_program ).

        if ls_trdir-subc ca '1MFS'.
          data(lt_textall) = go_reader->read_textpool( i_prog      = i_program
                                                       i_tab_langu = value #( ( spras = sy-langu ) ) ).

          lt_textpool = value #( lt_textall[ 1 ]-texts optional ).
          lv_description = value #( lt_textpool[ id = 'R' ]-entry optional ).

          if p_witext is initial.
            refresh lt_textpool.
          endif.
        endif.

      catch cx_siw_resource_failure into data(lx_rf).
        message lx_rf type 'I' display like 'E'.
        return.
    endtry.

    if p_debug = abap_true.
      break-point.
    endif.

    call function 'SIW_RFC_WRITE_REPORT'
      destination p_destin
      exporting
        i_name                = i_program
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

    if sy-subrc <> 0 or
       lv_msg   is not initial.
      message lv_msg type 'I' display like 'E'.
      return.
    endif.

    if ls_exception is not initial.
      message ls_exception-msgstring type 'I' display like 'E'.
      return.
    endif.

    if lt_textpool is not initial.

      if p_debug = abap_true.
        break-point.
      endif.

      call function 'SIW_RFC_WRITE_TEXTPOOL'
        destination p_destin
        exporting
          i_prog                = i_program
          i_langu               = sy-langu
          i_tab_textpool        = lt_textpool
        importing
          e_str_exception       = ls_exception
        exceptions
          system_failure        = 1 message lv_msg
          communication_failure = 2 message lv_msg.

      if sy-subrc <> 0 or
         lv_msg   is not initial.
        message lv_msg type 'I' display like 'E'.
        return.
      endif.

      if ls_exception is not initial.
        message ls_exception-msgstring type 'I' display like 'E'.
        return.
      endif.

    endif.

  endmethod.


  method copy_function.

    data: lt_code      type siw_tab_code,
          ls_exception type siw_str_msg,
          lv_msg       type text255.

    try.
        data(ls_funcinfo) = go_reader->read_funcinfo( p_func ).
        lt_code = go_reader->read_report( ls_funcinfo-include ).

        loop at lt_code assigning field-symbol(<ls_code>) from 2.
          if <ls_code>(2) <> '*"'.
            exit.
          endif.
          delete lt_code.
        endloop.

      catch cx_siw_resource_failure into data(lx_rf).
        message lx_rf type 'I' display like 'E'.
        return.
    endtry.

    if p_debug = abap_true.
      break-point.
    endif.

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

    if sy-subrc <> 0 or
       lv_msg   is not initial.
      message lv_msg type 'I' display like 'E'.
      return.
    endif.

    if ls_exception is not initial.
      message ls_exception-msgstring type 'I' display like 'E'.
      return.
    endif.

    message |{ p_func } kopyalandı| type 'S'.

  endmethod.


  method copy_method.

    data: lt_code      type siw_tab_code,
          ls_exception type siw_str_msg,
          lv_msg       type text255.

    try.
        go_reader->read_method_source( exporting i_clsname    = p_class
                                                 i_methodname = p_method
                                       importing e_tab_code   = lt_code  ).

      catch cx_siw_resource_failure into data(lx_rf).
        message lx_rf type 'I' display like 'E'.
        return.
    endtry.

    if p_debug = abap_true.
      break-point.
    endif.

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

    if sy-subrc <> 0 or
       lv_msg   is not initial.
      message lv_msg type 'I' display like 'E'.
      return.
    endif.

    if ls_exception is not initial.
      message ls_exception-msgstring type 'I' display like 'E'.
      return.
    endif.

    message |{ p_class } { p_method } kopyalandı| type 'S'.

  endmethod.


  method copy_struct.

    data: ls_exception type siw_str_msg,
          lv_msg       type text255.

    try.
        go_reader->read_stru( exporting i_name           = p_struc
                                        i_langu          = sy-langu
                              importing e_str_stru       = data(ls_str_stru)
                                        e_tab_stru_field = data(lt_stru_field) ).

      catch cx_siw_resource_failure into data(lx_rf).
        message lx_rf type 'I' display like 'E'.
        return.
    endtry.

    if p_debug = abap_true.
      break-point.
    endif.

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

    if sy-subrc <> 0 or
       lv_msg   is not initial.
      message lv_msg type 'I' display like 'E'.
      return.
    endif.

    if ls_exception is not initial.
      message ls_exception-msgstring type 'I' display like 'E'.
      return.
    endif.

    message |{ p_struc } kopyalandı| type 'S'.

  endmethod.

endclass.
