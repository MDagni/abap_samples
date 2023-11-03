************************************************************************
* Developer        : Mehmet Dağnilak
* Description      : Paralel RFC yöntemiyle sipariş simülasyonu örneği
************************************************************************
* History
*----------------------------------------------------------------------*
* User-ID     Date      Description
*----------------------------------------------------------------------*
* MDAGNILAK   20221125  Program created
* <userid>    yyyymmdd  <short description of the change>
************************************************************************

report zdagni_sd_order_simulate.

parameters: p_vbeln  type vbak-vbeln obligatory memory id aun,
            p_orders type i default 40,
            p_items  type i default 20,
            p_disabl as checkbox.

start-of-selection.

  perform main.

*&---------------------------------------------------------------------*
*&      Form  main
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form main.

  data: lt_orders type zdagni_sd_order_simulate_tab,
        ls_order  type zdagni_sd_order_simulate,
        ls_item   type bapiitemin,
        lv_start  type timestampl,
        lv_end    type timestampl.

  ls_order = value #(
                      orderkey = ''
                    ).

  "Mevcut bir siparişi örnek alarak sipariş verilerini oluştur.
  "Örnek bulmak için SE16H işlem kodunda WB2_V_VBAK_VBAP2 tablosunu VBELN'e göre gruplayarak
  "kullanabilirsiniz.
  select single
         auart as doc_type,
         vkorg as sales_org,
         vtweg as distr_chan,
         spart as division,
         waerk as currency
         from vbak
         into corresponding fields of @ls_order-order_header_in
         where vbeln = @p_vbeln.

  select single
         prsdt as price_date,
         zterm as pmnttrms
         from vbkd
         into corresponding fields of @ls_order-order_header_in
         where vbeln = @p_vbeln.

  select parvw as partn_role,
         kunnr as partn_numb
         from vbpa
         into corresponding fields of table @ls_order-order_partners
         where vbeln = @p_vbeln
           and parvw in ('AG','WE').

  ls_item = value #(
                    itm_number = 0
                    material   = ''
                    req_qty    = 5000
                   ).

  select distinct matnr
         from vbap
         into table @data(lt_matnr)
         where vbeln = @p_vbeln.

  do p_items times.
    ls_item-itm_number = sy-index * 100.
    ls_item-material   = lt_matnr[ ( sy-index - 1 ) mod lines( lt_matnr ) + 1 ].
    append ls_item to ls_order-order_items_in.
  enddo.

  do p_orders times.
    ls_order-orderkey = conv numc5( sy-index ).
    insert ls_order into table lt_orders.
  enddo.

*  try.
*      lt_orders[ 2 ]-order_header_in-pmnttrms = 'S004'.
*      lt_orders[ 3 ]-order_header_in-pmnttrms = 'XXXX'.
*    catch cx_sy_itab_line_not_found.
*  endtry.

*--------------------------------------------------------------------*
  get time stamp field lv_start.

  call function 'ZDAGNI_SD_ORDER_SIMULATE'
    exporting
      disable_credit_check = abap_true
      disable_parallel     = p_disabl
    changing
      orders               = lt_orders.

  get time stamp field lv_end.
*--------------------------------------------------------------------*

  data(lv_time) = cl_abap_tstmp=>subtract( tstmp1 = lv_end
                                           tstmp2 = lv_start ).

  write:/ lv_time.

  "İşlenemeyen var mı kontrol et. Normalde olmaması gerekir.
  loop at lt_orders assigning field-symbol(<ls_order>) where processed = abap_false.
    write:/ <ls_order>-orderkey, 'işlenememiş!!!'.
  endloop.

endform.          " main
