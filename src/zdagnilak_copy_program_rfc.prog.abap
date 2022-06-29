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
parameters: program radiobutton group prg,
            p_name  type syrepid memory id zcopy_name.
selection-screen skip.
parameters: function radiobutton group prg,
            p_func   type tfdir-funcname memory id zcopy_func.
selection-screen skip.
parameters: method   radiobutton group prg,
            p_class  type seoclsname memory id zcopy_class,
            p_method type seocpdname memory id zcopy_method.
selection-screen end of block b1.

selection-screen begin of block b2 with frame.
parameters: p_destin type rfcdest obligatory memory id vers_dest.
selection-screen end of block b2.

data: gv_debug type i.

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN
*&---------------------------------------------------------------------*
at selection-screen.
  if sscrfields-ucomm eq 'DEBUG'.
    gv_debug = 1 - gv_debug.
    message |Debug mode { gv_debug }| type 'S'.
    clear sscrfields-ucomm.
  endif.

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

  data: lt_code        type siw_tab_code,
        lt_textpool    type textpool_table,
        lv_name        type syrepid,
        lv_description type repti,
        ls_exception   type siw_str_msg,
        lv_msg         type text255.

  case abap_true.
    when program.
      lv_name = p_name.

    when function.
      call function 'FUNCTION_EXISTS'
        exporting
          funcname           = p_func
        importing
          include            = lv_name
        exceptions
          function_not_exist = 1
          others             = 2.
      if sy-subrc <> 0.
        message 'Fonksiyon mevcut değil!' type 'I'.
        return.
      endif.

    when method.
      cl_oo_classname_service=>get_method_include(
        exporting
          mtdkey                = value #( clsname = p_class cpdname = p_method )
          with_enhancements     = abap_true
          with_alias_resolution = abap_true
        receiving
          result                = lv_name
        exceptions
          class_not_existing    = 1
          method_not_existing   = 2 ).

      if sy-subrc <> 0.
        message id sy-msgid type 'I' number sy-msgno
          with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
          display like sy-msgty.
        return.
      endif.

  endcase.

  select single subc into @data(lv_progty)
         from trdir
         where name eq @lv_name.

  if sy-subrc ne 0.
    message 'Program bulunamadı!' type 'I'.
    return.
  endif.

  read report lv_name into lt_code.

  if lv_progty ca '1MFS'.
    read textpool lv_name into lt_textpool language sy-langu.
    lv_description = value #( lt_textpool[ id = 'R' ]-entry optional ).
  endif.

  if gv_debug = 1.
    break-point.
  endif.

  case abap_true.
    when program
      or function.

      call function 'SIW_RFC_WRITE_REPORT'
        destination p_destin
        exporting
          i_name                = lv_name
          i_tab_code            = lt_code
          i_extension           = ''
          i_object              = ''
          i_objname             = ''
          i_progtype            = lv_progty
          i_description         = lv_description
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

    if gv_debug = 1.
      break-point.
    endif.

    call function 'SIW_RFC_WRITE_TEXTPOOL'
      destination p_destin
      exporting
        i_prog                = lv_name
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

  message |Program { lv_name } kopyalandı| type 'S'.

endform.          " main
