************************************************************************
* Developer        : Mehmet Dağnilak
* Description      : Background'da çalışabilen Excel Upload örneği
************************************************************************
* History
*----------------------------------------------------------------------*
* User-ID     Date      Description
*----------------------------------------------------------------------*
* MDAGNILAK   20210212  Program created
* <userid>    yyyymmdd  <short description of the change>
************************************************************************
report zdagnilak_excel_upload.

tables sscrfields.

*&---------------------------------------------------------------------*
*& SELECTION-SCREEN
*&---------------------------------------------------------------------*
selection-screen begin of block bl1 with frame.
  parameters p_file type rlgrap-filename.
selection-screen end of block bl1.

selection-screen function key 1.

*&--------------------------------------------------------------------*
*& CLASS DEFINITION
*&--------------------------------------------------------------------*
class lcl_main definition final create public.

  public section.

    methods initialization.

    methods at_selection_screen.

    methods choose_file.

    methods excel_sablon.

    methods upload_file.

    methods display_data.

  private section.

    "Excel'den yüklenecek veri
    types: begin of ty_exceltab,
             asart type rm06e-asart,
             ekorg type ekko-ekorg,
             lifnr type ekko-lifnr,
             anfdt type rm06e-anfdt,
             matnr type mara-matnr,
             maktx type makt-maktx,
             menge type ekpo-menge,
             meins type ekpo-meins,
           end of ty_exceltab.

    "Ekranda gösterilecek veri
    types: begin of ty_data,
             light type c length 1,
             asart type rm06e-asart,
             ekorg type ekko-ekorg,
             lifnr type ekko-lifnr,
             anfdt type rm06e-anfdt,
             ebelp type ekpo-ebelp,
             matnr type ekpo-matnr,
             txz01 type ekpo-txz01,
             menge type ekpo-menge,
             meins type ekpo-meins,
             hata  type bapi_msg,
           end of ty_data.

    data gt_data type table of ty_data.
    data go_alv  type ref to cl_salv_table.

endclass.


*&---------------------------------------------------------------------*
*& INITIALIZATION
*&---------------------------------------------------------------------*
initialization.
  data(main) = new lcl_main( ).
  main->initialization( ).

*&---------------------------------------------------------------------*
*& AT SELECTION-SCREEN
*&---------------------------------------------------------------------*
at selection-screen.
  main->at_selection_screen( ).

at selection-screen on value-request for p_file.
  main->choose_file( ).

*&---------------------------------------------------------------------*
*& START-OF-SELECTION
*&---------------------------------------------------------------------*
start-of-selection.
  if p_file is initial.
    message 'Lütfen geçerli bir dosya yükleyiniz.' type 'I'.
    return.
  endif.

  main->upload_file( ).
  main->display_data( ).

*&--------------------------------------------------------------------*
*& CLASS IMPLEMENTATION
*&--------------------------------------------------------------------*
class lcl_main implementation.

  method initialization.

    concatenate icon_export 'Excel Şablonu İndir' into sscrfields-functxt_01.

  endmethod.


  method at_selection_screen.

    case sscrfields-ucomm.
      when 'FC01'.
        main->excel_sablon( ).
    endcase.

  endmethod.


  method choose_file.

    data: lt_files type filetable,
          lv_rc    type i.

    cl_gui_frontend_services=>file_open_dialog( exporting default_extension = '.xlsx'
                                                          file_filter       = cl_gui_frontend_services=>filetype_excel
                                                changing  file_table        = lt_files
                                                          rc                = lv_rc ).

    if lt_files is not initial.
      p_file = lt_files[ 1 ]-filename.
    endif.

  endmethod.


  method excel_sablon.

    data lt_exceltab type table of ty_exceltab.

    append value ty_exceltab( asart = 'AN'
                              ekorg = '2000'
                              lifnr = '420002'
                              anfdt = sy-datum
                              matnr = '51111100'
                              maktx = 'xxx'
                              menge = '1234'
                              meins = 'ST' )
           to lt_exceltab.

    try.
        cl_salv_table=>factory( importing r_salv_table = go_alv
                                changing  t_table      = lt_exceltab ).

        data(l_xml) = go_alv->to_xml( xml_type = if_salv_bs_xml=>c_type_xlsx ).

        call function 'XML_EXPORT_DIALOG'
          exporting
            i_xml                      = l_xml
            i_default_extension        = 'xlsx'
            i_initial_directory        = ''
            i_default_file_name        = 'Excel yükleme örnek.xlsx'
            i_mask                     = cl_gui_frontend_services=>filetype_excel
          exceptions
            application_not_executable = 1
            others                     = 2.

        if sy-subrc <> 0.
          message id sy-msgid type 'I' number sy-msgno
                  with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
                  display like sy-msgty.
        endif.

      catch cx_root into data(lr_err).
        message lr_err type 'I' display like 'E'.
    endtry.

  endmethod.


  method upload_file.

    data: lt_contents type solix_tab,
          ls_excel    type ty_exceltab,
          ls_data     type ty_data.

    field-symbols: <lt_table>  type standard table,
                   <lv_field1> type data,
                   <lv_field2> type data.

    "Excel dosyasını yükle
    cl_gui_frontend_services=>gui_upload( exporting  filename   = |{ p_file }|
                                                     filetype   = 'BIN'
                                          importing  filelength = data(lv_file_size)
                                          changing   data_tab   = lt_contents[]
                                          exceptions others     = 1 ).

    if sy-subrc = 0.
      data(lv_contents) = cl_bcs_convert=>solix_to_xstring( it_solix = lt_contents
                                                            iv_size  = lv_file_size ).
    else.
      message id sy-msgid type 'I' number sy-msgno
              with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
              display like sy-msgty.
      return.
    endif.

    "Dosyanın içindeki veriyi internal table olarak al. Tablonun tüm alanları String tipinde oluyor.
    try.
        data(lr_fdt_xl) = new cl_fdt_xl_spreadsheet( document_name = conv #( p_file )
                                                     xdocument     = lv_contents ).

        lr_fdt_xl->if_fdt_doc_spreadsheet~get_worksheet_names( importing worksheet_names = data(lt_worksheets) ).

        data(lr_dref) = lr_fdt_xl->if_fdt_doc_spreadsheet~get_itab_from_worksheet( lt_worksheets[ 1 ] ).

        assign lr_dref->* to <lt_table>.

      catch cx_fdt_excel_core into data(lr_err).
        message lr_err type 'I' display like 'E'.
        return.
    endtry.

    data(lo_struc) = cast cl_abap_structdescr( cl_abap_structdescr=>describe_by_data( ls_excel ) ).

    "Başlık satırını sil
    delete <lt_table> index 1.

    "Okunan tabloyu bizim internal table'ımıza aktar.
    loop at <lt_table> assigning field-symbol(<ls_line>).

      clear ls_excel.

      loop at lo_struc->components assigning field-symbol(<ls_component>).
        assign component sy-tabix of structure ls_excel to <lv_field1>.
        assign component sy-tabix of structure <ls_line> to <lv_field2>.

        try.
            case <ls_component>-type_kind.
              when cl_abap_structdescr=>typekind_date.
                <lv_field1> = translate( val = <lv_field2> from = `-` to = `` ).

              when others.
                <lv_field1> = <lv_field2>.
            endcase.

          catch cx_sy_conversion_error into data(lx_conv).
            message lx_conv type 'I' display like 'E'.
            return.
        endtry.

      endloop.

      "Okunan veriyi ekranda gösterilecek formata dönüştür
      clear ls_data.
      move-corresponding ls_excel to ls_data.

      ls_data-ebelp = sy-tabix * 10.
      ls_data-light = '2'.

      call function 'CONVERSION_EXIT_ALPHA_INPUT'
        exporting
          input  = ls_excel-lifnr
        importing
          output = ls_data-lifnr.

      call function 'CONVERSION_EXIT_MATN1_INPUT'
        exporting
          input  = ls_excel-matnr
        importing
          output = ls_data-matnr.

      call function 'CONVERSION_EXIT_CUNIT_INPUT'
        exporting
          input    = ls_excel-meins
          language = sy-langu
        importing
          output   = ls_data-meins
        exceptions
          others   = 0.

      select single maktx from makt
        into ls_data-txz01
        where matnr = ls_data-matnr
          and spras = sy-langu.

      if sy-subrc <> 0.
        ls_data-txz01 = ls_excel-maktx.
        ls_data-hata  = |Malzeme kodu SAP'de tanımlı değil.|.
        ls_data-light = '1'.
      endif.

      append ls_data to gt_data.

    endloop.

  endmethod.


  method display_data.

    check gt_data is not initial.

    try.
        cl_salv_table=>factory( importing r_salv_table = go_alv
                                changing  t_table      = gt_data ).

        "Çizgili görünüm
        go_alv->get_display_settings( )->set_striped_pattern( abap_true ).

        "Düzen ayarları
        data(lo_layout) = go_alv->get_layout( ).
        lo_layout->set_key( value #( report = sy-repid ) ).
        lo_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).
        lo_layout->set_default( abap_false ).

        "Sıralamalar
        data(lo_sorts) = go_alv->get_sorts( ).
        lo_sorts->add_sort( columnname = 'EBELP' ).

        "Toplamlar
        data(lo_aggrs) = go_alv->get_aggregations( ).
        lo_aggrs->add_aggregation( 'MENGE' ).

        "Sütun ayarları
        data(lo_columns) = go_alv->get_columns( ).
        lo_columns->set_optimize( ).
        lo_columns->set_key_fixation( ).
        lo_columns->set_exception_column( 'LIGHT' ).

        "SE11 veri yapısını ALV'deki sütunlara kopyala.
        lo_columns->apply_ddic_structure( 'EKKO' ).
        lo_columns->apply_ddic_structure( 'EKPO' ).

        "Sütun özelliklerini değiştir
        loop at lo_columns->get( ) reference into data(ls_columns).

          data(lo_column) = cast cl_salv_column_table( ls_columns->r_column ).

          case ls_columns->columnname.
            when 'EBELP'.
              lo_column->set_key( abap_false ).
          endcase.

        endloop.

        "Görüntüle
        go_alv->display( ).

      catch cx_salv_error into data(lx_salv).
        message lx_salv type 'I' display like 'E'.
    endtry.

  endmethod.

endclass.
