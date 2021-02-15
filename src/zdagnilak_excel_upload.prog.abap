*** GUI/OLE bağımsız Excel Upload örneği
report zdagnilak_excel_upload.

selection-screen begin of block b1 with frame.
parameters: p_file type ibipparms-path obligatory.
selection-screen end of block b1 .

*--------------------------------------------------------------------*
* at selection screen
*--------------------------------------------------------------------*
at selection-screen on value-request for p_file.

  data: lv_rc         type i,
        lt_file_table type filetable,
        ls_file_table type file_table.

  call method cl_gui_frontend_services=>file_open_dialog
    exporting
      window_title = 'Select a file'
    changing
      file_table   = lt_file_table
      rc           = lv_rc
    exceptions
      others       = 1.
  if sy-subrc = 0.
    read table lt_file_table into ls_file_table index 1.
    p_file = ls_file_table-filename.
  endif.


start-of-selection.
  data(gr_log) = new cl_ptu_message( ).

  perform get_data.

  if gr_log->has_messages( ).
    gr_log->display_log( iv_as_popup = abap_true
                         iv_use_grid = abap_true ).
  endif.

form get_data.

  data: lt_xtab     type tsfixml,
        lv_xcontent type xstring.

  field-symbols: <lt_table> type standard table.

  cl_gui_frontend_services=>gui_upload(
         exporting
           filename     = conv #( p_file )
           filetype     = 'BIN'
         importing
           filelength  =  data(lv_filesize)
         changing
           data_tab     = lt_xtab
         exceptions
           others       = 1 ).

  if sy-subrc = 0.
    call function 'SCMS_BINARY_TO_XSTRING'
      exporting
        input_length = lv_filesize
      importing
        buffer       = lv_xcontent
      tables
        binary_tab   = lt_xtab
      exceptions
        failed       = 1
        others       = 2.
  endif.

  if sy-subrc <> 0.
    gr_log->add_message_simple( ).
    return.
  endif.

  try.
      data(lo_excel) = new cl_fdt_xl_spreadsheet(
                              document_name = conv #( p_file )
                              xdocument     = lv_xcontent ) .

      lo_excel->if_fdt_doc_spreadsheet~get_worksheet_names( importing worksheet_names = data(lt_worksheets) ).

      data(lr_table) = lo_excel->if_fdt_doc_spreadsheet~get_itab_from_worksheet( lt_worksheets[ 1 ] ).

      assign lr_table->*  to <lt_table>.

      gr_log->add_text( iv_type = 'I' iv_text = | Dosyadan { lines( <lt_table> ) - 1 } satır okundu.| ).

    catch cx_fdt_excel_core into data(lr_err).
      gr_log->add_text( iv_type = 'E' iv_text = |Excel dosya yüklenemedi: { lr_err->get_text( ) }| ).
      return.

  endtry .

* Yüklenen dosyanın içeriğini ekranda göster
  cl_demo_output=>write( <lt_table> ).

  data(lv_html) = cl_demo_output=>get( ).

  cl_abap_browser=>show_html(
      title        = |Dosya datalar|
      size         = cl_abap_browser=>xlarge
      html_string  = lv_html
      context_menu = abap_true
      check_html   = abap_false ).

endform.
