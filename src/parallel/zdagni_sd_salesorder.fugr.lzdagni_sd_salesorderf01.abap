*&---------------------------------------------------------------------*
*&      Include  LZDAGNI_SD_SALESORDERF01
*&---------------------------------------------------------------------*


*&---------------------------------------------------------------------*
*&      Form  PARALLEL_RUN
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form parallel_run changing ev_error type xfeld.

* RFC altyapısını hazırla
  perform clear_variables.

  perform initialize_pbt_environment changing ev_error.
  check ev_error is initial.

* Her bir sipariş için RFC çağır
  loop at <gt_orders> assigning field-symbol(<ls_order>).
    perform call_bapi_rfc using <ls_order>-orderkey <ls_order>.
  endloop.

* RFC'lerin hepsi tamamlanana kadar bekle
  wait until gv_rcv_jobs >= gv_snd_jobs.

endform.          " PARALLEL_RUN

*&---------------------------------------------------------------------*
*&      Form  SEQUENTIAL_RUN
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form sequential_run.

* Her bir sipariş için RFC fonksiyonunu normal fonksiyon gibi çağır
  loop at <gt_orders> assigning field-symbol(<ls_order>).

    call function 'ZDAGNI_SD_ORDER_SIMULATE_RFC'
      exporting
        order_header_in      = <ls_order>-order_header_in
        disable_credit_check = gv_disable_credit_check
      tables
        order_items_in       = <ls_order>-order_items_in
        order_partners       = <ls_order>-order_partners
        order_schedule_in    = <ls_order>-order_schedule_in
        extensionin          = <ls_order>-extensionin
        partneraddresses     = <ls_order>-partneraddresses
        order_items_out      = <ls_order>-order_items_out
        order_schedule_ex    = <ls_order>-order_schedule_ex
        order_condition_ex   = <ls_order>-order_condition_ex
        order_incomplete     = <ls_order>-order_incomplete
        messagetable         = <ls_order>-messagetable.

    <ls_order>-processed = abap_true.

  endloop.

endform.          " SEQUENTIAL_RUN

*&---------------------------------------------------------------------*
*&      Form  CLEAR_VARIABLES
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form clear_variables.

  clear: gv_snd_jobs,
         gv_rcv_jobs.

endform.

*&---------------------------------------------------------------------*
*&      Form  INITIALIZE_PBT_ENVIRONMENT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form initialize_pbt_environment changing ev_error type flag.

  clear ev_error.

  ""Parallel Background Tasks" ortamını hazırla
  do.
    call function 'SPBT_INITIALIZE'
      exporting
        group_name                     = gv_server_group
      exceptions
        invalid_group_name             = 1
        internal_error                 = 2
        pbt_env_already_initialized    = 3
        currently_no_resources_avail   = 4
        no_pbt_resources_found         = 5
        cant_init_different_pbt_groups = 6
        others                         = 7.

    case sy-subrc.
      when 0 or 3 or 6.
        "pbt_env_already_initialized ve cant_init_different_pbt_groups hataları önemli değil,
        "işlemeye devam edebilir.
        exit. "do

      when 4.
        "currently_no_resources_avail hatası alınmışsa kaynaklar boşalana kadar denemeye devam edilecek.
        perform progress using 'Paralel işleme kaynakları dolu, boşalana kadar bekleniyor...'.
        ev_error = '1'.
        wait up to 1 seconds.

      when 1.
        "invalid_group_name hatasını programcının düzeltmesi gerekir
        message id sy-msgid type 'E' number sy-msgno
                with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.

      when 2 or 5 or 7.
        "İstenmeyen bir hata oluştu.
        "Dışarıdan RFC çağrılarında bu mesaj görüntülenemez, ama en azından ön yüzde test ederken fark edilir.
        message id sy-msgid type 'I' number sy-msgno
                with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
                display like sy-msgty.
        message 'Paralel işleme başlatılamıyor, seri işleme yapılacak!!!' type 'I'.
        ev_error = abap_true.
    endcase.

  enddo.

  if ev_error = '1'.
    perform progress using 'Paralel işleme başlatıldı...'.
    clear ev_error.
  endif.

endform.

*&---------------------------------------------------------------------*
*&      Form  progress
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form progress using msg type clike.

  call function 'SAPGUI_PROGRESS_INDICATOR'
    exporting
      percentage = 99
      text       = msg.

endform.          " progress

*&---------------------------------------------------------------------*
*&      Form  CALL_BAPI_RFC
*&---------------------------------------------------------------------*
*       Call BAPI using RFC
*----------------------------------------------------------------------*
form call_bapi_rfc using iv_taskname type zdagni_sd_order_simulate-orderkey
                         is_order    type zdagni_sd_order_simulate.

  data: lv_first_try type abap_bool,
        lv_msg       type bapi_msg,
        lv_rfcdest   type rfcdest.

  "Kaynaklar dolduğunda yeniden çağrı yapabilmek için döngüye gir.
  do.

    "BAPI'yi çağır. TABLES kısmında sadece gönderilen değerler yer almalı. BAPI'den dönen
    "değerler RETRIEVE_RFC_RESULT formunda okunacak.
    call function 'ZDAGNI_SD_ORDER_SIMULATE_RFC'
      starting new task iv_taskname
      destination in group gv_server_group
      performing retrieve_rfc_result on end of task
      exporting
        order_header_in       = is_order-order_header_in
        disable_credit_check  = gv_disable_credit_check
      tables
        order_items_in        = is_order-order_items_in
        order_partners        = is_order-order_partners
        order_schedule_in     = is_order-order_schedule_in
        extensionin           = is_order-extensionin
        partneraddresses      = is_order-partneraddresses
      exceptions
        communication_failure = 1 message lv_msg
        system_failure        = 2 message lv_msg
        resource_failure      = 3.

    case sy-subrc.
      when 0.
        "Çağrı başarılı
        gv_snd_jobs = gv_snd_jobs + 1.
        exit. "do

      when 1 or 2.
        "RFC sunucusuna ulaşılamadı. Bu sunucuyu geçici olarak devre dışı bırak.
        call function 'SPBT_GET_PP_DESTINATION'
          importing
            rfcdest = lv_rfcdest.

        call function 'SPBT_DO_NOT_USE_SERVER'
          exporting
            server_name                 = conv pbtsrvname( lv_rfcdest )
          exceptions
            invalid_server_name         = 1
            no_more_resources_left      = 2
            pbt_env_not_initialized_yet = 3
            others                      = 4.

      when 3.
        "Tüm sunucu kaynakları dolu. Önceki çağrılardan en az birinin işi bitene kadar bekle,
        "sonra bu çağrıyı tekrar dene.
        data(lv_last_rcv) = gv_rcv_jobs.

        if lv_first_try = space.
          lv_first_try = abap_true.
          "İlk deneme. En az bir çağrının işi bitene kadar veya 1 saniye bekle, sonra tekrar dene.
          wait for asynchronous tasks until gv_rcv_jobs > lv_last_rcv up to 1 seconds.
          "wait for asynchronous tasks until gv_rcv_jobs >= gv_snd_jobs up to 1 seconds.
        else.
          "İkinci deneme. İlk denemede sonlanan iş olmadığı için daha uzun süre bekle.
          wait for asynchronous tasks until gv_rcv_jobs > lv_last_rcv up to 5 seconds.
          "wait for asynchronous tasks until gv_rcv_jobs >= gv_snd_jobs up to 5 seconds.

          "SY-SUBRC 0 olursa önceki çağrılardan biri bitmiş demektir, devam et. 0 değilse
          "sistemsel bir sorun olabilir, ancak ne yapılabilir bilemiyorum. Denemeye devam et.
          if sy-subrc = 0.
            clear lv_first_try.
          else.
            "Sistemsel sorun - denemeye devam
          endif.
        endif.
    endcase.

  enddo.

endform.

*&---------------------------------------------------------------------*
*&      Form  RETRIEVE_RFC_RESULT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form retrieve_rfc_result using iv_taskname.

  "RFC fonksiyonun çalışması bittiğinde bu form çağrılır. RFC'den dönen sonuçları al.

  assign <gt_orders>[ orderkey = iv_taskname ] to field-symbol(<ls_order>).
  check sy-subrc = 0.

  receive results from function 'ZDAGNI_SD_ORDER_SIMULATE_RFC'
    tables
      order_items_out    = <ls_order>-order_items_out
      order_schedule_ex  = <ls_order>-order_schedule_ex
      order_condition_ex = <ls_order>-order_condition_ex
      order_incomplete   = <ls_order>-order_incomplete
      messagetable       = <ls_order>-messagetable
    exceptions
      communication_failure = 1
      system_failure        = 2.

  add 1 to gv_rcv_jobs.

  if sy-subrc = 0.
    <ls_order>-processed = abap_true.
  else.
    "error handling?
  endif.

endform.
