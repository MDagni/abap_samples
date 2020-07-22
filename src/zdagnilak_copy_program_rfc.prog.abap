report zdagnilak_copy_program_rfc.

parameters: p_name   type syrepid obligatory memory id zcopy_rid,
            p_progty type subc default '1'.
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

  break dnx_mdagnila.

  read report p_name into lt_code.
  if sy-subrc ne 0.
    message 'Program bulunamadı!' type 'I'.
    return.
  endif.

  if p_progty eq '1'.
    read textpool p_name into lt_textpool language sy-langu.
    lv_description = lt_textpool[ id = 'R' ]-entry.
  endif.

  call function 'SIW_RFC_WRITE_REPORT'
    destination p_destin
    exporting
      i_name          = p_name
      i_tab_code      = lt_code
      i_extension     = ''
      i_object        = ''
      i_objname       = ''
      i_progtype      = p_progty
      i_description   = lv_description
    importing
      e_str_exception = lv_msg.

  if lv_msg is initial.
    message 'Program kopyalandı' type 'S'.
  else.
    message lv_msg type 'I' display like 'E'.
  endif.

endform.          " main
