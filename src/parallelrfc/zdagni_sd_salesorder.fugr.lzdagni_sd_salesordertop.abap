function-pool zdagni_sd_salesorder.           "MESSAGE-ID ..

data: gv_disable_credit_check type abap_bool,
      gv_server_group         type rzlli_apcl,
      gv_snd_jobs             type i,
      gv_rcv_jobs             type i.

field-symbols: <gt_orders> type zdagni_sd_order_simulate_tab.

* INCLUDE LZDAGNI_SD_SALESORDERD...            " Local class definition
