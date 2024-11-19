*&---------------------------------------------------------------------*
*& Report ZDAGNILAK_RFC_TEST
*&---------------------------------------------------------------------*
*& RFC fonksiyonları test ekranı
*& Test edilecek fonksiyonlar programa ve seçim ekranına manuel eklenmelidir.
*& Tablo görüntüleme kısmı dinamik olarak çalışıyor.
*&
*& M.Dağnilak 16.11.2024
*&---------------------------------------------------------------------*
report zdagnilak_rfc_test.

*&--------------------------------------------------------------------*
*& SELECTION SCREEN
*&--------------------------------------------------------------------*
data: begin of so,
        matno type zbbs_urun_kodu,
        matnr type matnr,
        kunnr type kunnr,
      end of so.

"Fonksiyon seçimi
selection-screen begin of block bl1 with frame.
  parameters p_funct type vrm_value-key obligatory as listbox visible length 70 user-command func.
selection-screen end of block bl1.

selection-screen begin of block bl2 with frame.
  selection-screen: begin of tabbed block subselect for 6 lines,
                    end of block subselect.
selection-screen end of block bl2.

parameters p_debug as checkbox.

"Ortak elemanlar
selection-screen begin of screen 1999 as subscreen.
  select-options s_matno for so-matno.
  select-options s_matnr for so-matnr.
  select-options s_kunnr for so-kunnr.
  parameters p_kunnr type kunnr.
selection-screen end of screen 1999.

"ZBRS_UBY_002
selection-screen begin of screen 1001 as subscreen nesting level 1.
  parameters p_site type zbrs_hyb_store obligatory as listbox visible length 30.
  selection-screen include select-options s_matno.
selection-screen end of screen 1001.

"ZBRS_HYB_002
selection-screen begin of screen 1002 as subscreen nesting level 1.
  parameters: p_liste as checkbox,
              p_cis   as checkbox,
              p_bayi  as checkbox,
              p_b2b   as checkbox.
  selection-screen include select-options s_matno.
  selection-screen include select-options s_kunnr.
selection-screen end of screen 1002.

"ZBRS_SD_GET_B2B_STOCK
selection-screen begin of screen 1003 as subscreen nesting level 1.
  selection-screen include select-options s_matno.
selection-screen end of screen 1003.


*&--------------------------------------------------------------------*
*& CLASS DEFINITIONS
*&--------------------------------------------------------------------*
class lcl_functions definition final create public.

  public section.
    data gt_functions type vrm_values.

    methods constructor.
    methods call.
    methods display.

  private section.
    data go_start_time type ref to if_abap_runtime.

    methods call_zbrs_uby_002.
    methods call_zbrs_hyb_002.
    methods call_zbrs_sd_get_b2b_stock.

endclass.


class lcl_report definition final create public.

  public section.
    methods initialization.
    methods at_selection_screen.

    methods display_tables.
    methods status_0100.
    methods user_command_0100.

endclass.


class lcl_tables definition final create private.

  public section.
    types lcl_table_type type ref to lcl_tables.

    class-data gt_tables     type standard table of lcl_table_type.
    class-data gv_active_tab type sy-tabix.

    class-methods add
      importing
        !name           type salv_de_function
      changing
        t_table         type standard table
      returning
        value(er_table) type ref to lcl_tables.

    methods display.

  private section.
    data mo_container type ref to cl_gui_docking_container.
    data mo_salv      type ref to cl_salv_table.
    data mt_table     type ref to data.
    data mv_name      type salv_de_function.
    data mv_index     type sy-tabix.

    methods on_added_function
      for event added_function of cl_salv_events_table
      importing
        e_salv_function.

endclass.


*&--------------------------------------------------------------------*
*& PROGRAM FLOW
*&--------------------------------------------------------------------*
initialization.
  data(go_report) = new lcl_report( ).
  data(go_functions) = new lcl_functions( ).
  go_report->initialization( ).

at selection-screen.
  go_report->at_selection_screen( ).

start-of-selection.

  go_functions->call( ).

*&--------------------------------------------------------------------*
*& LCL_FUNCTIONS
*&--------------------------------------------------------------------*
class lcl_functions implementation.

  method constructor.

    "Key değerleri selection-screen'deki screen numarasına karşılık gelir.
    gt_functions = value #( ( key = '1001' text = 'Malzeme anaverisi (ZBRS_UBY_002)' )
                            ( key = '1002' text = 'B2B/CIS Fiyat listesi (ZBRS_HYB_002)' )
                            ( key = '1003' text = 'B2B Stok listesi (ZBRS_SD_GET_B2B_STOCK)' ) ).

  endmethod.


  method call.

    go_start_time = cl_abap_runtime=>create_lr_timer( ).
    go_start_time->get_runtime( ).

    case p_funct.
      when '1001'.
        go_functions->call_zbrs_uby_002( ).
      when '1002'.
        go_functions->call_zbrs_hyb_002( ).
      when '1003'.
        go_functions->call_zbrs_sd_get_b2b_stock( ).
    endcase.

  endmethod.


  method display.

    data lv_time type sy-uzeit.

    check lcl_tables=>gt_tables is not initial.

    lv_time = go_start_time->get_runtime( ) / 1000000.

    message |Çalışma süresi: { lv_time time = user }| type 'S'.

    go_report->display_tables( ).

  endmethod.


  method call_zbrs_uby_002.

    data: it_matno       type zbbs_urun_kodu_tab,
          lv_langu       type syst-langu,
          lv_spras       type cskt-spras,
          malzeme        type zbrsuby0002_tt,
          t_zbrsubyt001t type zbrsubyt001t_tt,
          t_zbrsubyt002t type zbrsubyt002t_tt,
          t_zbrsubyt003t type zbrsubyt003t_tt,
          t_zbrsubyt004t type zbrsubyt004t_tt,
          t_zbrsubyt005t type zbrsubyt005t_tt,
          t_zbrsubyt006t type zbrsubyt006t_tt,
          t_zbrsubyt010t type zbrsubyt010t_tt,
          t_zbrsubyt010  type zbrsubyt010_tt,
          t_zbrsubyt011  type zbrsubyt011_tt,
          t_zbrsuby0004  type zbrsuby0004_tt.

    it_matno = value #( for wa in s_matno ( wa-low ) ).

    lv_langu = sy-langu.
    lv_spras = cond #( when p_site = 'CIS' then 'E' else 'T' ).

    if p_debug = abap_true.
      break-point ##NO_BREAK.
    endif.

    call function 'ZBRS_UBY_002'
      exporting
        i_store          = p_site
        spras            = lv_spras
        it_matno         = it_matno
      importing
        malzeme          = malzeme
        t_zbrsubyt001t   = t_zbrsubyt001t
        t_zbrsubyt002t   = t_zbrsubyt002t
        t_zbrsubyt003t   = t_zbrsubyt003t
        t_zbrsubyt004t   = t_zbrsubyt004t
        t_zbrsubyt005t   = t_zbrsubyt005t
        t_zbrsubyt006t   = t_zbrsubyt006t
        t_zbrsubyt010t   = t_zbrsubyt010t
        t_zbrsubyt010    = t_zbrsubyt010
        t_zbrsubyt011    = t_zbrsubyt011
        t_zbrsuby0004    = t_zbrsuby0004
      exceptions
        dil_anahtari_bos = 1
        others           = 2.

    set locale language lv_langu.

    lcl_tables=>add( exporting name = 'MALZEME       ' changing t_table = malzeme        ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT001T' changing t_table = t_zbrsubyt001t ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT002T' changing t_table = t_zbrsubyt002t ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT003T' changing t_table = t_zbrsubyt003t ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT004T' changing t_table = t_zbrsubyt004t ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT005T' changing t_table = t_zbrsubyt005t ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT006T' changing t_table = t_zbrsubyt006t ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT010T' changing t_table = t_zbrsubyt010t ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT010 ' changing t_table = t_zbrsubyt010  ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBYT011 ' changing t_table = t_zbrsubyt011  ).
    lcl_tables=>add( exporting name = 'T_ZBRSUBY0004 ' changing t_table = t_zbrsuby0004  ).

    display( ).

  endmethod.


  method call_zbrs_hyb_002.

    data: it_kunnr       type fagl_t_kunnr,
          it_matno       type zbbs_urun_kodu_tab,
          et_fiyat_bayi  type zbrs_hyb_t007,
          et_fiyat_b2b   type zbrs_hyb_t008,
          et_fiyat_cis   type zbrs_hyb_t009,
          et_fiyat_liste type zbrs_hyb_t020.

    if s_kunnr[] is not initial.
      select kunnr from kna1
        into table @it_kunnr
        where kunnr in @s_kunnr.

      if sy-subrc <> 0.
        return.
      endif.
    endif.

    it_matno = value #( for wa in s_matno ( wa-low ) ).

    if p_debug = abap_true.
      break-point ##NO_BREAK.
    endif.

    call function 'ZBRS_HYB_002'
      exporting
        i_bayi         = p_bayi
        i_b2b          = p_b2b
        i_cis          = p_cis
        i_liste        = p_liste
        it_kunnr       = it_kunnr
        it_matno       = it_matno
      tables
        et_fiyat_bayi  = et_fiyat_bayi
        et_fiyat_b2b   = et_fiyat_b2b
        et_fiyat_cis   = et_fiyat_cis
        et_fiyat_liste = et_fiyat_liste.

    lcl_tables=>add( exporting name = 'ET_FIYAT_LISTE' changing t_table = et_fiyat_liste ).
    lcl_tables=>add( exporting name = 'ET_FIYAT_CIS  ' changing t_table = et_fiyat_cis   ).
    lcl_tables=>add( exporting name = 'ET_FIYAT_BAYI ' changing t_table = et_fiyat_bayi  ).
    lcl_tables=>add( exporting name = 'ET_FIYAT_B2B  ' changing t_table = et_fiyat_b2b   ).

    case abap_true.
      when p_liste.
        lcl_tables=>gv_active_tab = 1.
      when p_cis.
        lcl_tables=>gv_active_tab = 2.
      when p_bayi.
        lcl_tables=>gv_active_tab = 3.
      when p_b2b.
        lcl_tables=>gv_active_tab = 4.
      when others.
        message 'Bir fiyat türü seçiniz' type 'S'.
        return.
    endcase.

    display( ).

  endmethod.


  method call_zbrs_sd_get_b2b_stock.

    data: it_matno       type zbbs_urun_kodu_tab,
          et_stok        type zbrs_hyb_t011,
          et_cepdepostok type zbrs_hyb_t023.

    it_matno = value #( for wa in s_matno ( wa-low ) ).

    if p_debug = abap_true.
      break-point ##NO_BREAK.
    endif.

    call function 'ZBRS_SD_GET_B2B_STOCK'
      exporting
        it_matno       = it_matno
      tables
        et_stok        = et_stok
        et_cepdepostok = et_cepdepostok.

    lcl_tables=>add( exporting name = 'ET_STOK       ' changing t_table = et_stok ).
    lcl_tables=>add( exporting name = 'ET_CEPDEPOSTOK' changing t_table = et_cepdepostok   ).

    display( ).

  endmethod.

endclass.


*&--------------------------------------------------------------------*
*& LCL_REPORT
*&--------------------------------------------------------------------*
class lcl_report implementation.

  method initialization.

    data lt_values type vrm_values.

    "Fonksiyon seçimi
    get parameter id 'ZZFUNC' field p_funct.
    if sy-subrc <> 0.
      p_funct = go_functions->gt_functions[ 1 ]-key.
    endif.

    call function 'VRM_SET_VALUES'
      exporting
        id     = 'P_FUNCT'
        values = go_functions->gt_functions.

    "ZBRS_UBY_002 için site seçimi
    get parameter id 'ZZSITE' field p_site.
    if sy-subrc <> 0.
      p_site = 'B2B'.
    endif.

    lt_values = value #( ( key = 'B2B' text = 'B2B - Bayi ve OE müşterileri' )
                         ( key = 'CIS' text = 'CIS - İhracat' )
                         ( key = 'B2C' text = 'B2C - Lastik.com.tr' )
                         ( key = 'PRA' text = 'Price App' ) ).

    call function 'VRM_SET_VALUES'
      exporting
        id     = 'P_SITE'
        values = lt_values.

    "MATNO parametresini sadece eşittir seçilebilecek şekilde kısıtla.
    data(ls_restrict) = value sscr_restrict( opt_list_tab = value #( ( name    = '01'
                                                                       options = value #( eq = abap_true ) ) )
                                             ass_tab      = value #( kind    = 'S'
                                                                     sg_main = 'I'
                                                                     op_main = '01'
                                                                     ( name = 'S_MATNO' ) ) ).

    call function 'SELECT_OPTIONS_RESTRICT'
      exporting
        restriction = ls_restrict.

    subselect-prog  = sy-repid.
    subselect-dynnr = p_funct.

  endmethod.


  method at_selection_screen.

    set parameter id 'ZZFUNC' field p_funct.
    set parameter id 'ZZSITE' field p_site.

    subselect-dynnr = p_funct.

  endmethod.


  method display_tables.

    call screen '0100'.

  endmethod.


  method status_0100.

    data(lv_text) = go_functions->gt_functions[ key = p_funct ]-text.

    set pf-status 'ALV'.
    set titlebar '001' with lv_text.

    data(lo_table) = lcl_tables=>gt_tables[ lcl_tables=>gv_active_tab ].
    lo_table->display( ).

  endmethod.


  method user_command_0100.

    case sy-ucomm.
      when 'BACK'.
        leave to screen 0.
    endcase.

  endmethod.

endclass.


*&--------------------------------------------------------------------*
*& LCL_TABLE
*&--------------------------------------------------------------------*
class lcl_tables implementation.

  method add.

    er_table = new #( ).
    append er_table to gt_tables.

    er_table->mv_name  = name.
    er_table->mv_index = lines( gt_tables ).
    get reference of t_table into er_table->mt_table.

    if gv_active_tab is initial.
      gv_active_tab = 1.
    endif.

  endmethod.


  method display.

    field-symbols <table> type standard table.

    if mo_container is not initial.
      mo_container->set_visible( abap_true ).
      return.
    endif.

    try.
        mo_container = new #( side      = cl_gui_docking_container=>dock_at_left
                              extension = 5000 ).

        assign mt_table->* to <table>.

        cl_salv_table=>factory( exporting r_container  = mo_container
                                importing r_salv_table = mo_salv
                                changing  t_table      = <table> ).

        data(lo_display) = mo_salv->get_display_settings( ).
        lo_display->set_list_header( mv_name ).
        lo_display->set_striped_pattern( abap_true ).

        data(lo_layout) = mo_salv->get_layout( ).
        lo_layout->set_save_restriction( if_salv_c_layout=>restrict_none ).
        lo_layout->set_key( value #( report = |{ sy-repid }-{ p_funct }|
                                     handle = mv_index ) ).

        data(lo_functions) = mo_salv->get_functions( ).
        lo_functions->set_all( ).

        loop at gt_tables into data(lo_table).
          lo_functions->add_function( name     = lo_table->mv_name
                                      icon     = cond #( when lo_table->mv_name = mv_name
                                                         then icon_okay
                                                         else icon_view_table )
                                      text     = conv #( lo_table->mv_name )
                                      tooltip  = ''
                                      position = if_salv_c_function_position=>right_of_salv_functions ).
        endloop.

        set handler on_added_function for mo_salv->get_event( ).

        data(lo_columns) = mo_salv->get_columns( ).
        lo_columns->set_optimize( ).

        loop at lo_columns->get( ) reference into data(lr_column).

          data(lo_column) = cast cl_salv_column_list( lr_column->r_column ).

          "Sütun başlığı alan adıyla aynı olsun
          lo_column->set_short_text( '' ).
          lo_column->set_medium_text( '' ).
          lo_column->set_long_text( conv #( lr_column->columnname ) ).
          lo_column->set_fixed_header_text( 'L' ).

          "Conversion exit'i devre dışı bırak
          lo_column->set_edit_mask( '' ).

        endloop.

        mo_salv->display( ).

      catch cx_salv_msg into data(lx_salv).
        message lx_salv type 'I' display like 'E'.
      catch cx_salv_static_check into data(lx_check).
        message lx_check type 'I' display like 'E'.
    endtry.

  endmethod.


  method on_added_function.

    check e_salv_function <> mv_name.

    try.
        data(lo_new_table) = gt_tables[ table_line->mv_name = e_salv_function ].
        gv_active_tab = lo_new_table->mv_index.

        mo_container->set_visible( abap_false ).
        lo_new_table->display( ).

      catch cx_sy_itab_line_not_found.
        return.
    endtry.

  endmethod.

endclass.

*&---------------------------------------------------------------------*
*&      Module  STATUS_0100  OUTPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
module status_0100 output.

  go_report->status_0100( ).

endmodule.

*&---------------------------------------------------------------------*
*&      Module  USER_COMMAND_0100  INPUT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
module user_command_0100 input.

  go_report->user_command_0100( ).

endmodule.
