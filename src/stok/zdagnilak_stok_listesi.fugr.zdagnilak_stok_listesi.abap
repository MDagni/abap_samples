FUNCTION ZDAGNILAK_STOK_LISTESI.
*"----------------------------------------------------------------------
*"*"Local Interface:
*"  IMPORTING
*"     VALUE(I_MATNR) TYPE  MATNR
*"     VALUE(I_WERKS) TYPE  WERKS_D OPTIONAL
*"     VALUE(I_LGORT) TYPE  LGORT_D OPTIONAL
*"  EXPORTING
*"     VALUE(E_MENGE) TYPE  MENGE_D
*"  TABLES
*"      T_STOK STRUCTURE  ATPDS OPTIONAL
*"      T_IHTIYAC STRUCTURE  ATPCS OPTIONAL
*"----------------------------------------------------------------------

  include atpgxval.
  include mm61xval.

  data: p_atpcsx  type table of atpcs with header line,
        p_atpdsx  type table of atpds with header line,
        p_mdvex   type table of mdve with header line,
        p_t441vx  type table of t441v with header line,
        p_tmvfx   type table of tmvf with header line,
        p_atpdiax type table of atpdia with header line,
        p_atpca   type atpca,
        p_atpcb   type atpcb.

  ranges: r_werks for mard-werks,
          r_lgort for mard-lgort.

  if i_werks is not initial.
    r_werks = 'IEQ'.
    r_werks-low = i_werks.
    append r_werks.
  endif.

  if i_lgort is not initial.
    r_lgort = 'IEQ'.
    r_lgort-low = i_lgort.
    append r_lgort.
  endif.

  select werks from marc
    into table @data(lt_marc)
    where matnr  = @i_matnr
      and werks in @r_werks.

  loop at lt_marc assigning field-symbol(<ls_marc>).

    clear : p_atpca,
            p_atpcb,
            p_atpcsx[],
            p_atpcsx,
            p_atpdsx[],
            p_atpdsx,
            p_mdvex[],
            p_mdvex,
            p_t441vx[],
            p_t441vx,
            p_tmvfx[],
            p_tmvfx,
            p_atpdiax[],
            p_atpdiax.

    "P_ATPCSX
    p_atpcsx-matnr  = i_matnr.
    p_atpcsx-werks  = <ls_marc>-werks.
    p_atpcsx-prreg  = 'A'.   "SD siparişi

    p_atpcsx-chmod  = '051'.          "Mahsuplaştırma Brisa (T459K-BEDAR)
    p_atpcsx-delkz  = vbedc.          "Sipariş
    p_atpcsx-bdter  = sy-datum.
    p_atpcsx-trtyp  = mdakta.         "Görüntüle
    p_atpcsx-idxatp = '1'.            "Kontrol sırası
    p_atpcsx-resmd  = c_resmd_prop.   "proposal list
    p_atpcsx-chkflg = xflag.          "ihtiyaç kontrolü - evet/hayır
    "p_atpcsx-vbtyp  = 'C'.            "Satış siparişi
    p_atpcsx-xline  = 1.              "satır no
    p_atpcsx-bdmng  = 999999.         "İstenen miktar
    p_atpcsx-lgort  = i_lgort.

    append p_atpcsx.

    "P_ATPCA
    p_atpca-anwdg    = c_appl_expl_comp.  "explanation component
    p_atpca-azerg    = char1.             "no dialog
    p_atpca-rdmod    = chars.             "Münferit kayıtlar
    p_atpca-xenqmd   = c_xenqmd_nothing.  "neither read or set enqueue
    p_atpca-force_r3 = xflag.             "Yerel ATP kontrolü

    "Stok listesini al
    call function 'AVAILABILITY_CHECK_CONTROLLER'
      tables
        p_atpcsx      = p_atpcsx[]
        p_atpdsx      = p_atpdsx[]
        p_mdvex       = p_mdvex[]
        p_t441vx      = p_t441vx[]
        p_tmvfx       = p_tmvfx[]
        p_atpdiax     = p_atpdiax[]
      changing
        p_atpca       = p_atpca
        p_atpcb       = p_atpcb
      exceptions
        error         = 1
        error_message = 2
        others        = 3.

    if sy-subrc <> 0.
      continue.
    endif.

    p_atpdsx-ewerk = p_atpcsx-werks.
    modify p_atpdsx transporting ewerk where ewerk = ''.

*    "ATP miktarları yerine teyit edilen miktarı koy
*    if i_lgort   is not initial and
*       p_mdvex[] is not initial.
*
*      assign p_mdvex[ 1 ] to field-symbol(<p_mdvex>).
*
*      loop at p_atpdsx where delkz      = 'LB'
*                         and atpnr+6(4) = i_lgort.
*        p_atpdsx-qty = <p_mdvex>-mng02.
*        modify p_atpdsx.
*      endloop.
*    endif.

    append lines of p_atpdsx[] to t_stok[].
    append lines of p_atpcsx[] to t_ihtiyac[].
  endloop.

  "Sadece depo stoklarını döndür.
  delete t_stok where delkz <> 'LB'.

  if r_lgort is not initial.
    delete t_stok where atpnr+6(4) not in r_lgort.
  endif.

  loop at t_stok.
    e_menge = e_menge + t_stok-qty.
  endloop.

endfunction.
