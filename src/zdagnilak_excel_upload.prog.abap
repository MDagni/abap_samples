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

  field-symbols <tabfl> type standard table.

  data: l_bin_table type tsfixml,
        lv_xcontent type xstring.

  cl_gui_frontend_services=>gui_upload(
         exporting
           filename     = |{ p_file }|
           filetype     = 'BIN'
         importing
           filelength  =  data(l_bin_length)
         changing
           data_tab     = l_bin_table[]
         exceptions
           others       = 1 ).

  if sy-subrc = 0.
    call function 'SCMS_BINARY_TO_XSTRING'
      exporting
        input_length = l_bin_length
      importing
        buffer       = lv_xcontent
      tables
        binary_tab   = l_bin_table[]
      exceptions
        failed       = 1
        others       = 2.
  endif.

  if sy-subrc <> 0.
    gr_log->add_message_simple( ).
    return.
  endif.

  try.
      data(lr_fdt_xl) = new cl_fdt_xl_spreadsheet(
                              document_name = conv #( p_file )
                              xdocument     = lv_xcontent ) .

      lr_fdt_xl->if_fdt_doc_spreadsheet~get_worksheet_names( importing
                                                                worksheet_names = data(lt_worksheets) ).

      data(lr_dref) = lr_fdt_xl->if_fdt_doc_spreadsheet~get_itab_from_worksheet(
                                              lt_worksheets[ 1 ] ).

      assign lr_dref->*  to <tabfl>.


      gr_log->add_text( iv_type = 'I' iv_text = | Dosyadan { lines( <tabfl> ) - 1 } satır okundu.| ).

    catch cx_fdt_excel_core into data(lr_err).
      gr_log->add_text( iv_type = 'E' iv_text = |Excel dosya yüklenemedi: { lr_err->get_text( ) }| ).
      return.

  endtry .

* Yüklenen dosyanın içeriğini ekranda göster
  cl_demo_output=>write( <tabfl> ).

  data(lv_html) = cl_demo_output=>get( ).
  cl_abap_browser=>show_html(
      title        = |Dosya datalar|
      size         = cl_abap_browser=>xlarge
      html_string  = lv_html
      context_menu = abap_true
      check_html   = abap_false ).

endform.
