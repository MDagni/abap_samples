function zdagni_sd_order_simulate_rfc.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(ORDER_HEADER_IN) TYPE
*"        ZDAGNI_SD_ORDER_SIMULATE-ORDER_HEADER_IN
*"     VALUE(DISABLE_CREDIT_CHECK) TYPE  XFELD OPTIONAL
*"  TABLES
*"      ORDER_ITEMS_IN TYPE  ESALES_BAPIITEMIN_TAB
*"      ORDER_PARTNERS TYPE  ESALES_BAPIPARTNR_TAB
*"      ORDER_SCHEDULE_IN TYPE  CMP_T_SCHDL
*"      EXTENSIONIN TYPE  BAPIPAREX_TABLE
*"      PARTNERADDRESSES TYPE  BAPIADDR1_TAB
*"      ORDER_ITEMS_OUT TYPE  ESALES_BAPIITEMEX_TAB
*"      ORDER_SCHEDULE_EX TYPE  BAPISDHEDUTAB
*"      ORDER_CONDITION_EX TYPE  CMP_T_COND
*"      ORDER_INCOMPLETE TYPE  ZDAGNI_BAPIINCOMP_TAB
*"      MESSAGETABLE TYPE  BAPIRET2_TAB
*"----------------------------------------------------------------------
  data: ls_return type bapireturn.

* Performans nedeniyle kredi limiti kontrolünü devre dışı bırakılabilir
  if disable_credit_check = abap_true.
**    call function 'ZDAGNISDMST_DISABLE_LIMIT_CHECK'
**      exporting
**        iv_disabled = abap_true.
  endif.

* Simülasyon
  call function 'BAPI_SALESORDER_SIMULATE'
    exporting
      order_header_in    = order_header_in
    importing
      return             = ls_return
    tables
      order_items_in     = order_items_in
      order_partners     = order_partners
      order_schedule_in  = order_schedule_in
      extensionin        = extensionin
      partneraddresses   = partneraddresses
      order_items_out    = order_items_out
      order_schedule_ex  = order_schedule_ex
      order_condition_ex = order_condition_ex
      order_incomplete   = order_incomplete
      messagetable       = messagetable.

* Kredi limiti kontrolünü geri getir
  if disable_credit_check = abap_true.
**    call function 'ZDAGNISDMST_DISABLE_LIMIT_CHECK'
**      exporting
**        iv_disabled = abap_false.
  endif.

endfunction.
