* Screen yaratmadan ALV gösterimi
* cl_gui_container=>screen0 kullanımına örnek
* Kaynak:
* http://quelquepart.biz/article25/afficher-un-alv-objet-sans-creer-d-ecran-screen-painter

program zdagnilak_screenless_alv.

data: o_alv     type ref to cl_gui_alv_grid,
      t_sflight type table of sflight.

* Definition of an empty selection screen
selection-screen: begin of screen 1001,
                   end of screen 1001.

start-of-selection.

* Filling the data table for the ALV
  select * from sflight into table t_sflight.

* Creation of the alv object directly attached to the first screen
  create object o_alv
    exporting
      i_parent = cl_gui_container=>screen0.

* Passing data to the ALV
  call method o_alv->set_table_for_first_display
    exporting
      i_structure_name = 'SFLIGHT'
    changing
      it_outtab        = t_sflight.

* Display of the screen, the ALV appears!
  call selection-screen 1001.
