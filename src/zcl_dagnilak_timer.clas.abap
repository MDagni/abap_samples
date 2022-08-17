class zcl_dagnilak_timer definition
  public
  create protected .

  public section.

    data mv_seconds type i .
    data mv_started type i .
    data mv_last type i .

    class-methods start
      importing
        !iv_seconds     type i
      returning
        value(ro_timer) type ref to zcl_dagnilak_timer.
    methods finished
      returning
        value(rv_finished) type abap_bool .
  protected section.

  private section.
endclass.



class zcl_dagnilak_timer implementation.


  method finished.

    "Bekleme süresi kadar saniye geçmişse True dön.
    "Örnek:
    "  if lo_timer->finished( ).

    get run time field mv_last.

    if ( mv_last - mv_started ) >= ( mv_seconds * 1000000 ).
      rv_finished = abap_true.
    endif.

  endmethod.


  method start.

    "Kaç saniyeye kadar beklenecekse o kadar tutacak bir geri sayım sayacı oluştur.
    "Örnek:
    "  data(lo_timer) = zcl_dagnilak_timer=>start( 30 ).

    ro_timer = new #( ).

    ro_timer->mv_seconds = iv_seconds.
    get run time field ro_timer->mv_started.

  endmethod.
endclass.
