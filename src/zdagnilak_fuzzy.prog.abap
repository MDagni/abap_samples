report zdagnilak_fuzzy.

parameters: p_maktx type makt-maktx default '20555'. "205/55 vs şeklindeki tüm malzemeleri getirmesi gerekiyor

data:begin of so,
       matnr type matnr,
     end of so.

select-options s_matnr for so-matnr.

start-of-selection.

  types: begin of ty_result,
           matnr type makt-matnr,
           maktx type makt-maktx,
         end of ty_result.

  data: lr_data       type ref to data,
        lt_result     type table of ty_result,
        lv_sql        type string,
        lv_where_cond type string.

  try.
      lv_where_cond = cl_shdb_seltab=>combine_seltabs(
          it_named_seltabs = value #(
                ( name = 'MATNR' dref = ref #( s_matnr[] ) ) )
          iv_client_field = 'MANDT' ).
    catch cx_shdb_exception into data(lx_shdb_exc).
      message lx_shdb_exc type 'I'.
      return.
  endtry.

  get reference of lt_result into lr_data.

  replace all occurrences of |'| in p_maktx  with |''|.

  lv_where_cond = lv_where_cond && `  AND MATNR <> ''`.

  lv_sql =
       `SELECT DISTINCT "MATNR", "MAKTX" ` &&
       `FROM "MAKT" ` &&
       `WHERE CONTAINS( ( "MAKTX" ), '` && p_maktx && `', FUZZY( 0.8, 'similarCalculationMode=search' ) ) ` &&
       `AND (` && lv_where_cond && `)  WITH PARAMETERS( 'LOCALE' = 'CASE_INSENSITIVE' )`.

  "https://help.sap.com/viewer/691cb949c1034198800afde3e5be6570/2.0.02/en-US/f3d72af569ab4360b347c73ed4806067.html
*  lv_sql =
*      `SELECT DISTINCT "MATNR", "MAKTX" ` &&
*      `FROM "MAKT" ` &&
*      `WHERE CONTAINS( ( "MAKTX" ), '` && p_maktx && `', FUZZY( 0.8, 'similarCalculationMode=search' ) ) ` &&
*      `AND "MANDT" = '` && sy-mandt && `'  WITH PARAMETERS( 'LOCALE' = 'CASE_INSENSITIVE' )`.



  data(lo_connection) = cl_sql_connection=>get_connection( con_name = cl_sadl_dbcon=>get_default_dbcon( )
                                                           sharable = abap_true ).
  data(lo_statement) = lo_connection->create_statement( ).

  lo_statement->set_table_name_for_trace( 'MAKT' ).

  data(lo_result) = lo_statement->execute_query( lv_sql ).
  lo_result->set_param_table( itab_ref = lr_data ).


  while lo_result->next_package( ) > 0 ##NEEDED.
    " loop in case not all data is fetched with first call
  endwhile.

  lo_connection->close( ).

  sort lt_result by maktx.

  break-point.
