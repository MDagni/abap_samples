class ZCL_DAGNILAK_BATCH definition
  public
  final
  create public .

public section.

  data MT_BDCDATA type BDCDATA_TAB .

  methods BDC_DYNPRO
    importing
      !PROGRAM type BDCDATA-PROGRAM
      !DYNPRO type BDCDATA-DYNPRO .
  methods BDC_FIELD
    importing
      !FNAM type BDCDATA-FNAM
      !FVAL type SIMPLE .
  methods CALL_TRANSACTION
    importing
      !TCODE type SY-TCODE
      !DISMODE type CTU_PARAMS-DISMODE default 'N'
      !NOBINPT type CTU_PARAMS-NOBINPT optional
      !UPDMODE type CTU_PARAMS-UPDMODE optional
    exporting
      !RESULT type SY-SUBRC
      !MESSAGES type BAPIRET2_TAB .
  protected section.
  private section.
ENDCLASS.



CLASS ZCL_DAGNILAK_BATCH IMPLEMENTATION.


  method bdc_dynpro.

    append value #( program  = program
                    dynpro   = dynpro
                    dynbegin = abap_true
                  ) to mt_bdcdata.

  endmethod.


  method bdc_field.

    data: ls_bdcdata type bdcdata.

    ls_bdcdata-fnam = fnam.
    write fval to ls_bdcdata-fval left-justified.

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
                           messages into lt_message .

    result = sy-subrc.

    "Batch input mesajları her zaman hatadır, ama success olarak geliyor.
    modify lt_message from value #( msgtyp = 'E' ) transporting msgtyp where msgid eq '00'.

    call function 'CONVERT_BDCMSGCOLL_TO_BAPIRET2'
      tables
        imt_bdcmsgcoll = lt_message
        ext_return     = messages.

    refresh: mt_bdcdata.

  endmethod.
ENDCLASS.
