*** SALV üzerinden Excel Download örneği
report zdagnilak_excel_down.

data: begin of so,
        budat type bkpf-budat,
      end of so.

selection-screen begin of block b1 with frame title text-001.
parameters: p_bukrs type bkpf-bukrs obligatory memory id buk,
            p_gjahr like bkpf-gjahr obligatory default sy-datum(4).
select-options
            s_budat for so-budat obligatory default '20191201' to '20191231'.
parameters: p_file   type rlgrap-filename,  "path
            p_rowcnt type i default 800000 obligatory.

selection-screen end of block b1.

selection-screen begin of block b2 with frame title text-002.
parameters: p_excel  radiobutton group rad1 user-command seltyp,
            p_text   radiobutton group rad1,
            p_alv    radiobutton group rad1 default 'X',
            p_alvexp radiobutton group rad1.
selection-screen end of block b2.

data: begin of gt_out occurs 0,
        bukrs type bkpf-bukrs,
        hkont type bseg-hkont,
        txt50 type skat-txt50,
        gjahr type bkpf-gjahr,
        bldat type bkpf-bldat,
        budat type bkpf-budat,
        cpudt type bkpf-cpudt,
        cputm type bkpf-cputm,
        belnr type bkpf-belnr,
        buzei type bseg-buzei,
        sgtxt type bseg-sgtxt,
        shkzg type bseg-shkzg,
        wrbtr type bseg-wrbtr,
        waers type bkpf-waers,
        dmbtr type bseg-dmbtr,
        hwaer type bkpf-hwaer,
        usnam type bkpf-usnam,
      end of gt_out.

data: gv_path type string.

load-of-program.
  cl_gui_frontend_services=>get_desktop_directory( changing desktop_directory = gv_path ).
  cl_gui_cfw=>flush( ).
  p_file = gv_path. "= |{ gv_path }\\FIDT\\|.

at selection-screen on value-request for p_file.
  perform get_path using p_file.

at selection-screen.
  p_gjahr = s_budat-low(4).


start-of-selection.
  perform get_data.

end-of-selection.
  if p_alv = abap_true.
    perform display_alv.
  else.
    perform download_file.
  endif.

class lcl_main definition.
  public section.
    class-data: mr_salv      type ref to cl_salv_table.

    class-methods on_link_click for event link_click of cl_salv_events_table
      importing row column.


endclass.
class lcl_main implementation.
  method on_link_click.

    assign gt_out[ row ] to field-symbol(<wa_out>).

    set parameter id 'BUK' field <wa_out>-bukrs.
    set parameter id 'BLN' field <wa_out>-belnr.
    set parameter id 'GJR' field <wa_out>-gjahr.
    call transaction 'FB03' and skip first screen.

  endmethod.

endclass.
form get_data.

  select bkpf~bukrs,
         hkont,
         txt50,
         bkpf~gjahr,
         bldat,
         budat,
         cpudt,
         cputm,
         bkpf~belnr,
         buzei,
         sgtxt,
         shkzg,
         wrbtr,
         bkpf~waers,
         dmbtr,
         hwaer,
         usnam
             from bkpf
             join bseg
               on bkpf~bukrs = bseg~bukrs
              and bkpf~belnr = bseg~belnr
              and bkpf~gjahr = bseg~gjahr
             join t001
               on t001~bukrs = bkpf~bukrs
  left outer join skat
               on skat~ktopl = t001~ktopl
              and skat~saknr = bseg~hkont
              and skat~spras = 'T'
            where bkpf~bukrs eq @p_bukrs
              and bkpf~gjahr eq @p_gjahr
              and budat in @s_budat
         order by bkpf~bukrs, bkpf~gjahr, bkpf~belnr, buzei
  into corresponding fields of table @gt_out.



endform.
*&---------------------------------------------------------------------*
*&      Form  DOWNLOAD_FILE
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
form download_file .

  data: lt_file like table of gt_out,
        lv_part type numc3.

  gv_path = |{ gv_path }\\{ sy-datum+5 }{ sy-uzeit(3) }|.

*  p_rowcnt
  while lines( gt_out ) > 0.
    lv_part = sy-index .
    perform set_filename using lv_part.

    clear lt_file[].
    append lines of gt_out from 1 to p_rowcnt to lt_file .
    delete gt_out from 1 to p_rowcnt.
    if p_alvexp = abap_true..
      perform salv_export  tables lt_file  changing sy-subrc.
    else.
      perform sap_data_convert  tables lt_file changing sy-subrc.
    endif.

    if sy-subrc <> 0.
      message  |Dosya kaydedilemedi. Satır: { lines( lt_file )  number = user }|  type 'S'.
    else.
      message  |Dosya kaydedildi. Satır: { lines( lt_file ) number = user }|  type 'S'.
    endif.
  endwhile.

endform.

form get_path using  p_file.


  cl_gui_frontend_services=>directory_browse( exporting  initial_folder = gv_path
                                              changing   selected_folder = gv_path ).

  p_file = gv_path.


endform.                    " get_filename
*&---------------------------------------------------------------------*
*&      Form  SELECTION_SCREEN
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
form set_filename using p_part.
  data lv_code type i.

  p_file = |{ gv_path }\\{ p_bukrs }_{ p_gjahr+2 }{ s_budat-low+4 }_{ s_budat-high+4 }_{ p_part }.{ switch char4( p_text when abap_true then 'TXT' else 'XLSX') }|.

*  if sy-ucomm = 'ONLI'.
*    call method cl_gui_frontend_services=>file_delete
*      exporting
*        filename             = conv #( p_file )
*      changing
*        rc                   = lv_code
*      exceptions
*        file_delete_failed   = 1
*        cntl_error           = 2
*        error_no_gui         = 3
*        file_not_found       = 4
*        access_denied        = 5
*        unknown_error        = 6
*        not_supported_by_gui = 7
*        wrong_parameter      = 8
*        others               = 9.
*
*    if sy-subrc <> 0 and  sy-subrc <> 4.
*      message | { p_file } dosyasını siliniz. | type 'E'.
*    endif.
*  endif.

endform.
*&---------------------------------------------------------------------*
*&      Form  ALV_DISPLAY
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
form display_alv .

  try.
      cl_salv_table=>factory( importing
                                 r_salv_table = data(lr_salv)
                               changing
                                  t_table     = gt_out[] ).

      data(lr_columns) = lr_salv->get_columns( ).
      lr_columns->set_optimize( abap_true ).


* Get functions details
      lr_salv->get_functions( )->set_all( abap_true ).

      lr_salv->get_sorts( )->add_sort( 'BUKRS' ).
      lr_salv->get_sorts( )->add_sort( 'GJAHR' ).
      lr_salv->get_sorts( )->add_sort( 'BELNR' ).
      lr_salv->get_sorts( )->add_sort( 'BUZEI' ).
      lr_salv->get_aggregations( )->add_aggregation( 'DMBTR' ).
      lr_salv->get_aggregations( )->add_aggregation( 'WRBTR' ).

      loop at lr_salv->get_columns( )->get( ) assigning field-symbol(<col>) .

        data(lr_col) = cast cl_salv_column_table( <col>-r_column ).

        case <col>-columnname.
          when 'HKONT'.
            lr_col->set_text_column( 'TXT50' ).

          when 'BELNR'.
            lr_col->set_cell_type( if_salv_c_cell_type=>hotspot ).

          when 'DMBTR'.
            lr_col->set_currency( 'HWAER' ).

          when 'WRBTR'.
            lr_col->set_currency( 'WAERS' ).

        endcase.

      endloop.

      data(lr_layout) = lr_salv->get_layout( ).
      lr_layout->set_key( value = value #( report = sy-repid ) ).
      lr_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).
      lr_layout->set_default( abap_true ).

      data(lr_display) = lr_salv->get_display_settings( ).
      lr_display->set_striped_pattern( abap_true ).
      lr_display->set_list_header( 'FIS_DATA' ).

      lcl_main=>mr_salv = lr_salv.
      set handler lcl_main=>on_link_click for lr_salv->get_event( ).

      lr_salv->display( ).

    catch cx_salv_error into data(lx_salv).
      message lx_salv type 'I'.
  endtry.

endform.
*&---------------------------------------------------------------------*
*&      Form  EXCEL_EXPORT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
form salv_export  tables pt_file changing value(subrc) .

  try.
      data(lr_xlse) = cl_salv_export_tool=>create_for_excel( ref #( pt_file[]  ) ).
      data(lr_config) = lr_xlse->configuration( ).

      loop at cast cl_abap_structdescr( cl_abap_typedescr=>describe_by_data( pt_file ) )->components
                         assigning field-symbol(<wacomp>).
        lr_config->add_column( header_text  = conv #( <wacomp>-name )
                               field_name   = conv #( <wacomp>-name )
                               display_type = if_salv_export_column_conf=>display_types-text_view ).
      endloop.

      lr_xlse->read_result( importing
                              content            = data(lv_content)
                              mime_type          = data(lv_mimetype)
                              filename           = data(lv_filename)
                              t_messages_info    = data(lt_info)
                              t_messages_warning = data(lt_warning) ) .

      cl_salv_data_services=>download_xml_to_file( xcontent = lv_content
                                                   filename = |{ p_file }| ).
      subrc = 0.
    catch cx_root into data(lr_err).

      message lr_err type 'I' display like 'E'.
      subrc = 4.
  endtry.
endform.
*&---------------------------------------------------------------------*
*&      Form  SAP_DATA_CONVERT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*  -->  p1        text
*  <--  p2        text
*----------------------------------------------------------------------*
form sap_data_convert tables pt_file changing value(subrc) .

  call function 'SAP_DATA_CONVERT_WRITE_FILE'
    exporting
      i_servertyp       = switch truxs_server( p_excel when 'X' then 'OLE2' else 'PRS' )
      i_filename        = conv fileintern( p_file )
      i_fileformat      = switch truxs_fileformat( p_excel when 'X' then 'XLS' else 'TXT' )
      i_field_seperator = '|'
    tables
      i_tab_sender      = pt_file
    exceptions
      others            = 4.
  subrc = sy-subrc.
endform.
