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

report zdagnilak_mesh.

parameters: p_bukrs type bukrs obligatory default '0210' memory id buk,
            p_gjahr type gjahr obligatory default '2014'.

start-of-selection.
  perform main.


*&---------------------------------------------------------------------*
*&      Form  main
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
form main.

  types:
    "Belge tipi
    begin of ty_bkpf,
      bukrs type bkpf-bukrs,
      belnr type bkpf-belnr,
      bktxt type bkpf-bktxt,
    end of ty_bkpf,

    "Kalem tipi
    begin of ty_bseg,
      belnr type bseg-belnr,
      buzei type bseg-buzei,
      sgtxt type bseg-sgtxt,
    end of ty_bseg,

    "Belge tablosu
    ty_t_bkpf type sorted table of ty_bkpf with unique key bukrs belnr
              with non-unique sorted key docno components belnr,
    "Kalem tablosu
    ty_t_bseg type sorted table of ty_bseg with unique key belnr buzei,

    "Veri ve ilişki tanımı
    begin of mesh ty_mesh,
      heads type ty_t_bkpf association my_items  to items on belnr = belnr,
      items type ty_t_bseg association my_header to heads on belnr = belnr using key docno,
    end of mesh ty_mesh.

  "Veri alanı
  data: ls_data type ty_mesh.

  "Örnek veri
  select bukrs belnr bktxt
         up to 10000 rows
         into table ls_data-heads
         from bkpf
         where bukrs = p_bukrs
           and gjahr = p_gjahr
         order by primary key.

  select belnr buzei sgtxt
         up to 30000 rows
         into table ls_data-items
         from bseg
         where bukrs = p_bukrs
           and gjahr = p_gjahr
         order by primary key.

  "break-point.

  do 10000 times.

    "Sıradaki belge başlığını al
    data(ls_head) = ls_data-heads[ sy-index ].

    format color col_heading.
    write:/ sy-index, ls_head-belnr, ls_head-bktxt.

    format color col_normal.

    "Belgenin ilk kalemini bul
    try.
        data(ls_item1) = ls_data-heads\my_items[ ls_head ].
        write:/ ls_item1-belnr, ls_item1-buzei, ls_item1-sgtxt.
      catch cx_sy_itab_line_not_found.
        write:/ '001 Not found'.
    endtry.

    "Belgenin başka bir kalemini bul
    try.
        data(ls_item2) = ls_data-heads\my_items[ ls_head buzei = '003' ].
        write:/ ls_item2-belnr, ls_item2-buzei, ls_item2-sgtxt.
      catch cx_sy_itab_line_not_found.
        write:/ '003 Not found'.
    endtry.

    "Belgenin tüm kalemlerini al
    loop at ls_data-heads\my_items[ ls_head ] into data(ls_item3).
      write:/ ls_item3-belnr, ls_item3-buzei, ls_item3-sgtxt.
    endloop.

    if sy-subrc ne 0.
      write:/ 'No items exist'.
    endif.

  enddo.

endform.          " main2
