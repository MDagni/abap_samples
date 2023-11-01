report zdagnilak_fiyat_suresi line-size 255.

tables komg.

parameters: p_tabnam type t681-kotab  obligatory default 'A882',
            p_kschl  type rv13a-kschl obligatory default 'FYAT',
            p_datam  type rv130-datam obligatory default '20231012',
            p_datbi  type rv13a-datbi obligatory default '99991231',
            p_dismod type ctu_params-dismode obligatory default 'N',
            p_test   as checkbox default abap_true.
selection-screen skip.
select-options: s_vkorg for komg-vkorg,
                s_vtweg for komg-vtweg,
                s_zterm for komg-zterm.

class lcl_main definition.

  public section.
    methods run.
    methods f4_tabnam.

  private section.

    types: begin of ty_values,
             f001  type char30,
             f002  type char30,
             f003  type char30,
             f004  type char30,
             f005  type char30,
             f006  type char30,
             f007  type char30,
             f008  type char30,
             f009  type char30,
             f010  type char30,
             count type i,
           end of ty_values.

    data gt_fields type standard table of t681e-sefeld.
    data gt_values type table of ty_values.
    data gs_t681   type t681.

    methods get_keys.

    methods do_batch.
endclass.


class lcl_batch definition.

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

initialization.
  data(go_main) = new lcl_main( ).

at selection-screen on value-request for p_tabnam.
  go_main->f4_tabnam( ).

start-of-selection.

  go_main->run( ).


class lcl_main implementation.

  method f4_tabnam.

    data ls_t681 type t681.

    call function 'RV_GET_CONDITION_TABLES'
      exporting
        application            = 'V'
        condition_type         = p_kschl
        condition_use          = 'A'
        like_pf4               = abap_true
      importing
        table_t681             = ls_t681
      exceptions
        invalid_condition_type = 1
        missing_parameter      = 2
        no_selection_done      = 3
        no_table_found         = 4
        table_not_valid        = 5
        others                 = 6.

    if sy-subrc <> 0.
      return.
    endif.

    if ls_t681-kotab is not initial.
      p_tabnam = ls_t681-kotab.
    endif.

  endmethod.


  method run.

    get_keys( ).

    do_batch( ).

  endmethod.


  method get_keys.

    data: lv_fields type string,
          lv_group  type string,
          lv_where  type string.

    select single *
           from t681
           into @gs_t681
           where kotab = @p_tabnam.

    select sefeld
           into table @gt_fields
           from t681e
           where kvewe   = @gs_t681-kvewe
             and kotabnr = @gs_t681-kotabnr
             and fsetyp  = 'A'
           order by fselnr.

    if gt_fields is not initial.
      loop at gt_fields assigning field-symbol(<lv_field>).
        lv_fields = |{ lv_fields } { <lv_field> } as F{ conv numc3( sy-tabix ) },|.
        lv_group = |{ lv_group } { <lv_field> },|.
      endloop.
      lv_fields = |{ lv_fields } count(*) as count|.
      lv_group = substring( val = lv_group
                            len = strlen( lv_group ) - 1 ).
    else.
      lv_fields = 'count(*) as count'.
    endif.

    if line_exists( gt_fields[ table_line = 'VKORG' ] ).
      lv_where = lv_where && `vkorg in @s_vkorg and `.
    endif.

    if line_exists( gt_fields[ table_line = 'VTWEG' ] ).
      lv_where = lv_where && `vtweg in @s_vtweg and `.
    endif.

    if line_exists( gt_fields[ table_line = 'ZTERM' ] ).
      lv_where = lv_where && `zterm in @s_zterm and `.
    endif.

    if lv_where is not initial.
      lv_where = substring( val = lv_where
                            len = strlen( lv_where ) - 4 ).
    endif.

    select distinct (lv_fields)
           into corresponding fields of table @gt_values
           from (p_tabnam)
           where kappl = @gs_t681-kappl
             and kschl = @p_kschl
             and datbi <> '99991231'
             and datbi >= @p_datam
             and datab <= @p_datam
             and (lv_where)
           group by (lv_group)
           order by (lv_group).

  endmethod.


  method do_batch.

    data: lt_tables  type standard table of t682ia,
          lt_tables2 type standard table of t682ia.
    field-symbols <lv_f> type ty_values-f001.

    check gt_values is not initial.

    select single *
           into @data(ls_t685)
           from t685
           where kvewe = @gs_t681-kvewe
             and kappl = @gs_t681-kappl
             and kschl = @p_kschl.

    call function 'COND_READ_ACCESSES'
      exporting
        i_kvewe    = ls_t685-kvewe
        i_kappl    = ls_t685-kappl
        i_kozgf    = ls_t685-kozgf
      tables
        t682ia_tab = lt_tables.

    sort lt_tables by kotabnr.
    delete adjacent duplicates from lt_tables comparing kotabnr.
    sort lt_tables by kolnr.

    data(lt_vfields) = cast cl_abap_structdescr( cl_abap_structdescr=>describe_by_data( gt_values[ 1 ] ) )->get_components( ).

    loop at gt_values assigning field-symbol(<ls_value>).

      new-line.
      do lines( gt_fields ) times.
        assign component sy-index of structure <ls_value> to <lv_f>.
        write <lv_f>.
      enddo.

      write <ls_value>-count.

      if p_test = abap_true.
        continue.
      endif.

      data(lo_batch) = new lcl_batch( ).

      lo_batch->bdc_dynpro( program = 'SAPMV13A'
                            dynpro  = '0100' ).
      lo_batch->bdc_field( fnam = 'BDC_OKCODE'
                           fval = '/00' ).
      lo_batch->bdc_field( fnam = 'RV13A-KSCHL'
                           fval = p_kschl ).

      if lines( lt_tables ) > 1.

        lt_tables2 = lt_tables.

        data(lv_line) = conv numc2( line_index( lt_tables2[ kotabnr = p_tabnam+1 ] ) ).

        lo_batch->bdc_dynpro( program = 'SAPLV14A'
                              dynpro  = '0100' ).
        lo_batch->bdc_field( fnam = 'RV130-SELKZ(01)'
                             fval = '' ).

        while lv_line > 12.
          lo_batch->bdc_field( fnam = 'BDC_OKCODE'
                               fval = '=P+' ).
          lo_batch->bdc_dynpro( program = 'SAPLV14A'
                                dynpro  = '0100' ).

          if lines( lt_tables2 ) > 24.
            lv_line = lv_line - 12.
            delete lt_tables2 from 1 to 12.
          else.
            lv_line = lv_line - ( lines( lt_tables2 ) - 12 ).
            delete lt_tables2 from 1 to ( lines( lt_tables2 ) - 12 ).
          endif.

        endwhile.

        lo_batch->bdc_field( fnam = |RV130-SELKZ({ lv_line })|
                             fval = 'X' ).
        lo_batch->bdc_field( fnam = 'BDC_OKCODE'
                             fval = '=WEIT' ).

      endif.

      lo_batch->bdc_dynpro( program = |RV13{ p_tabnam }|
                            dynpro  = '1000' ).
      lo_batch->bdc_field( fnam = 'BDC_OKCODE'
                           fval = '=ONLI' ).
      lo_batch->bdc_field( fnam = 'SEL_DATE'
                           fval = p_datam ).

      do lines( gt_fields ) times.
        assign component sy-index of structure <ls_value> to <lv_f>.
        lo_batch->bdc_field( fnam = conv #( lt_vfields[ sy-index ]-name )
                             fval = <lv_f> ).
      enddo.

      lo_batch->bdc_dynpro( program = 'SAPMV13A'
                            dynpro  = |1{ p_tabnam+1 }| ).
      lo_batch->bdc_field( fnam = 'BDC_OKCODE'
                           fval = '=MARL' ).

      lo_batch->bdc_dynpro( program = 'SAPMV13A'
                            dynpro  = |1{ p_tabnam+1 }| ).
      lo_batch->bdc_field( fnam = 'BDC_OKCODE'
                           fval = '=TICH' ).

      lo_batch->bdc_dynpro( program = 'SAPMV13A'
                            dynpro  = '0210' ).
      lo_batch->bdc_field( fnam = 'BDC_OKCODE'
                           fval = '=DUEB' ).
      lo_batch->bdc_field( fnam = 'RV13A-DATAB'
                           fval = '' ).
      lo_batch->bdc_field( fnam = 'RV13A-DATBI'
                           fval = p_datbi ).

      lo_batch->bdc_dynpro( program = 'SAPMV13A'
                            dynpro  = |1{ p_tabnam+1 }| ).
      lo_batch->bdc_field( fnam = 'BDC_OKCODE'
                           fval = '=SICH' ).

      lo_batch->call_transaction( exporting tcode    = 'VK12'
                                            dismode  = p_dismod
                                  importing result   = data(lv_result)
                                            messages = data(lt_messages) ).

      write:/ 'Sonuç = ', lv_result.

      loop at lt_messages assigning field-symbol(<ls_message>).
        write:/ <ls_message>-type, <ls_message>-message.
      endloop.

      refresh lt_messages.

    endloop.

  endmethod.

endclass.


class lcl_batch implementation.

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

    call function 'CONVERT_BDCMSGCOLL_TO_BAPIRET2'
      tables
        imt_bdcmsgcoll = lt_message
        ext_return     = messages.

    refresh mt_bdcdata.

  endmethod.

endclass.
