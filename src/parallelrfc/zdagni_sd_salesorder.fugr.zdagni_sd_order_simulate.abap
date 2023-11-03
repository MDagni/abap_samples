FUNCTION ZDAGNI_SD_ORDER_SIMULATE.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(DISABLE_CREDIT_CHECK) TYPE  XFELD OPTIONAL
*"     VALUE(DISABLE_PARALLEL) TYPE  XFELD OPTIONAL
*"     VALUE(SERVER_GROUP) TYPE  RZLLI_APCL DEFAULT
*"       'parallel_generators'
*"  CHANGING
*"     REFERENCE(ORDERS) TYPE  ZDAGNI_SD_ORDER_SIMULATE_TAB
*"----------------------------------------------------------------------
* ORDERS tablosundaki her bir satır için BAPI_SALESORDER_SIMULATE fonksiyonu paralel olarak
* çağrılır. ORDERKEY alanına geri dönen değerleri ayrıştırabilmek için istediğiniz değeri
* koyabilirsiniz, bu değerler eşsiz olmalıdır.

  check orders is not initial.

  "Global değerler
  gv_disable_credit_check = disable_credit_check.
  gv_server_group         = server_group.
  assign orders to <gt_orders>.

  "İşleme başla
  if disable_parallel is initial.
    "Paralel işleme
    data(lv_error) = abap_false.
    perform parallel_run changing lv_error.

    "Paralel işleyemezse sıralı işlemeye geç
    if lv_error = abap_true.
      perform sequential_run.
    endif.

  else.
    "Sıralı işleme
    perform sequential_run.
  endif.

endfunction.
