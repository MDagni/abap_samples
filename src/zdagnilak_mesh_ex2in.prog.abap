************************************************************************
* Developer        : Mehmet Dağnilak
* Description      : Mesh association
************************************************************************
* History
*----------------------------------------------------------------------*
* User-ID     Date      Description
*----------------------------------------------------------------------*
* MDAGNILAK   20200420  Program created
* <userid>    yyyymmdd  <short description of the change>
************************************************************************

report zdagnilak_mesh_ex2in.

perform main2.


*&---------------------------------------------------------------------*
*&      Form  main2
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form main2.

  types: begin of ty_bkpf,
           belnr type belnr_d,
           bukrs type bukrs,
         end of ty_bkpf,

         begin of ty_bseg,
           belnr type belnr_d,
           buzei type buzei,
         end of ty_bseg,

         ty_t_bkpf type sorted table of ty_bkpf with unique key bukrs belnr
                     with non-unique sorted key cle_belnr components belnr ,
         ty_t_bseg type sorted table of ty_bseg with non-unique key belnr buzei,

         begin of mesh ty_mesh,
           head type ty_t_bkpf association my_items to item on belnr = belnr,
           item type ty_t_bseg association my_header to head on belnr = belnr using key cle_belnr,
         end of mesh ty_mesh.

  data: ls_data type ty_mesh.

  select belnr bukrs up to 10000 rows
         into table ls_data-head
         from bkpf
         where bukrs = '0210'
           and gjahr = '2014'
         order by primary key.

  select belnr buzei up to 30000 rows
         into table ls_data-item
         from bseg
         where bukrs = '0210'
           and gjahr = '2014'
         order by primary key.

*  break-point.

  do 10000 times.
    data(lv_belnr) = ls_data-head[ sy-index ]-belnr.
    write:/ sy-index, lv_belnr.

    try.
*        data(ls_mesh) = ls_data-head\my_items[ ls_data-head[ key cle_belnr belnr = lv_belnr ] ].

        data(ls_mesh2) = ls_data-head\my_items[ value #( belnr = lv_belnr ) ].
        write: ls_mesh2-belnr, ls_mesh2-buzei.

        loop at ls_data-head\my_items[ value #( belnr = lv_belnr ) ] into data(ls_item).
          write:/ ls_item-belnr, ls_item-buzei.
        endloop.

        if sy-subrc ne 0.
          write:/ 'item not exists'.
        endif.

      catch cx_sy_itab_line_not_found.
        write: 'Not found'.
    endtry.
  enddo.

endform.          " main2
