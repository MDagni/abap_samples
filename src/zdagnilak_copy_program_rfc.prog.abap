report zdagnilak_copy_program_rfc.

parameters: p_name type syrepid obligatory memory id zcopy_rid.
selection-screen skip.
parameters: p_destin type rfcdest obligatory memory id vers_dest.

start-of-selection.

  perform main.

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

  select single subc into @data(lv_progty)
         from trdir
         where name eq @p_name.

  if sy-subrc ne 0.
    message 'Program bulunamadı!' type 'I'.
    return.
  endif.

  read report p_name into lt_code.

  if lv_progty eq '1'.
    read textpool p_name into lt_textpool language sy-langu.
    lv_description = lt_textpool[ id = 'R' ]-entry.
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

  if sy-subrc eq 0 and
     lv_msg is initial.
    write |Program { p_name } kopyalandı| color col_positive.
  else.
    message lv_msg type 'I' display like 'E'.
  endif.

endform.          " main
