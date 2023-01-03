* Screen yaratmadan ALV gösterimi
* cl_gui_container=>screen0 kullanımına örnek
* Kaynak:
* http://quelquepart.biz/article25/afficher-un-alv-objet-sans-creer-d-ecran-screen-painter
* ALV Grid yerine SALV Table kullanacak şekilde güncellendi.
* Bu şekilde gösterim yapılınca yüksek çözünürlüklü ekranlarda ekranın sağ tarafının boş kalması da
* engellenmiş oluyor.

program zdagnilak_screenless_alv2.

tables: vbak.

select-options: s_erdat for vbak-erdat.

data: lo_alv type ref to cl_salv_table.

start-of-selection.

* Filling the data table for the ALV
  select * from vbak
    up to 200 rows
    into table @data(lt_vbak)
    where erdat in @s_erdat.

* Creation of the alv object directly attached to the first screen
  cl_salv_table=>factory(
    exporting
      r_container  = cl_gui_container=>screen0
    importing
      r_salv_table = lo_alv
    changing
      t_table      = lt_vbak ).

  lo_alv->get_functions( )->set_all( ).
  lo_alv->get_columns( )->set_optimize( ).

  "Display ALV table
  lo_alv->display( ).
  cl_abap_list_layout=>suppress_toolbar( ).
  write space.
