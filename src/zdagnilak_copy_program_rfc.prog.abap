report zdagnilak_copy_program_rfc.

tables: sscrfields.

parameters: program  radiobutton group prg,
            p_name   type syrepid memory id zcopy_name,
            function radiobutton group prg,
            p_func   type tfdir-funcname memory id zcopy_func.

selection-screen skip.
parameters: p_destin type rfcdest obligatory memory id vers_dest.

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

  data: lt_code        type siw_tab_code,
        lt_textpool    type textpool_table,
        lv_description type repti,
        lv_msg         type siw_str_msg.

  if function eq abap_true.
    call function 'FUNCTION_EXISTS'
      exporting
        funcname           = p_func
      importing
        include            = p_name
      exceptions
        function_not_exist = 1
        others             = 2.
    if sy-subrc <> 0.
      message 'Fonksiyon mevcut değil!' type 'I'.
      return.
    endif.
  endif.

  select single subc into @data(lv_progty)
         from trdir
         where name eq @p_name.

  if sy-subrc ne 0.
    message 'Program bulunamadı!' type 'I'.
    return.
  endif.

  read report p_name into lt_code.

  if lv_progty ca '1MFS'.
    read textpool p_name into lt_textpool language sy-langu.
    lv_description = value #( lt_textpool[ id = 'R' ]-entry optional ).
  endif.

  call function 'SIW_RFC_WRITE_REPORT'
    destination p_destin
    exporting
      i_name                = p_name
      i_tab_code            = lt_code
      i_extension           = ''
      i_object              = ''
      i_objname             = ''
      i_progtype            = lv_progty
      i_description         = lv_description
    importing
      e_str_exception       = lv_msg
    exceptions
      system_failure        = 1 message lv_msg
      communication_failure = 2 message lv_msg.

  if sy-subrc ne 0 or
     lv_msg is not initial.
    message lv_msg type 'I' display like 'E'.
    return.
  endif.

  if lt_textpool is not initial.
    call function 'SIW_RFC_WRITE_TEXTPOOL'
      destination p_destin
      exporting
        i_prog                = p_name
        i_langu               = sy-langu
        i_tab_textpool        = lt_textpool
      importing
        e_str_exception       = lv_msg
      exceptions
        system_failure        = 1 message lv_msg
        communication_failure = 2 message lv_msg.

    if sy-subrc ne 0 or
       lv_msg is not initial.
      message lv_msg type 'I' display like 'E'.
      return.
    endif.
  endif.

  message |Program { p_name } kopyalandı| type 'S'.

endform.          " main
