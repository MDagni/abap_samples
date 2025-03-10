class zcl_dagnilak_batch definition
  public final
  create public.

  public section.

    data mt_bdcdata type bdcdata_tab.

    methods bdc_dynpro
      importing
        !program type bdcdata-program
        !dynpro  type bdcdata-dynpro.

    methods bdc_field
      importing
        fnam type bdcdata-fnam
        fval type simple.

    methods bdc_field2
      importing
        fnam  type bdcdata-fnam
        fval  type numeric
        meins type meins.

    methods bdc_field3
      importing
        fnam  type bdcdata-fnam
        fval  type numeric
        waers type waers.

    methods call_transaction
      importing
        tcode     type sy-tcode
        dismode   type ctu_params-dismode default 'N'
        nobinpt   type ctu_params-nobinpt optional
        updmode   type ctu_params-updmode optional
      exporting
        !result   type sy-subrc
        !messages type bapiret2_tab.
endclass.


class zcl_dagnilak_batch implementation.

  method bdc_dynpro.

    append value #( program  = program
                    dynpro   = dynpro
                    dynbegin = abap_true )
           to mt_bdcdata.

  endmethod.


  method bdc_field.

    data ls_bdcdata type bdcdata.

    ls_bdcdata-fnam = fnam.
    write fval to ls_bdcdata-fval left-justified.

    append ls_bdcdata to mt_bdcdata.

  endmethod.


  method bdc_field2.

    data ls_bdcdata type bdcdata.

    ls_bdcdata-fnam = fnam.
    write fval to ls_bdcdata-fval unit meins left-justified.

    append ls_bdcdata to mt_bdcdata.

  endmethod.


  method bdc_field3.

    data ls_bdcdata type bdcdata.

    ls_bdcdata-fnam = fnam.
    write fval to ls_bdcdata-fval currency waers left-justified.

    append ls_bdcdata to mt_bdcdata.

  endmethod.


  method call_transaction.

    data: lt_message type table of bdcmsgcoll,
          ls_opt     type ctu_params.

    ls_opt-dismode = dismode.
    ls_opt-nobinpt = nobinpt.
    ls_opt-updmode = updmode.

    call transaction tcode using mt_bdcdata
         options from ls_opt
         messages into lt_message.

    result = sy-subrc.

    "Batch input mesajları her zaman hatadır, ama success olarak geliyor.
    modify lt_message from value #( msgtyp = 'E' ) transporting msgtyp where msgid = '00'.

    loop at lt_message transporting no fields where msgtyp ca 'EAX'.
      result = 4.
    endloop.

    call function 'CONVERT_BDCMSGCOLL_TO_BAPIRET2'
      tables
        imt_bdcmsgcoll = lt_message
        ext_return     = messages.

    refresh mt_bdcdata.

  endmethod.

endclass.
