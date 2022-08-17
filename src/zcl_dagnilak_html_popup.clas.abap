class zcl_dagnilak_html_popup definition
  public
  create protected .

*"* public components of class ZCL_DAGNILAK_HTML_POPUP
*"* do not include other source files here!!!
  public section.
    type-pools icon .

    constants c_closewin type salv_de_function value 'CLOSEWIN' ##NO_TEXT.
    constants c_refresh type salv_de_function value 'REFRESH' ##NO_TEXT.
    data mo_dialogbox type ref to cl_gui_dialogbox_container read-only .
    data mo_html type ref to cl_gui_html_viewer read-only .

    class-methods display
      importing
        !url            type string
        !caption        type string default 'Web sayfası'   ##NO_TEXT
        !width          type int4 default 1100
        !height         type int4 default 320
        !top            type int4 default 60
        !left           type int4 default 100
      returning
        value(ro_popup) type ref to zcl_dagnilak_html_popup .

    methods on_dialog_close
         for event close of cl_gui_dialogbox_container .

  protected section.
*"* protected components of class ZCL_DAGNILAK_HTML_POPUP
*"* do not include other source files here!!!
  private section.
*"* private components of class ZCL_DAGNILAK_HTML_POPUP
*"* do not include other source files here!!!
endclass.



class zcl_dagnilak_html_popup implementation.


  method display.

    try.
        create object ro_popup.

*       Dialog penceresini yarat. Ölçüler piksel değil SAP ölçü birimi cinsinden.
        create object ro_popup->mo_dialogbox
          exporting
            width   = width
            height  = height
            top     = top
            left    = left
            caption = conv text255( caption )
            metric  = cl_gui_dialogbox_container=>metric_default.

*       HTML nesnesi yarat
        create object ro_popup->mo_html
          exporting
            parent = ro_popup->mo_dialogbox.

*       Event'ler
        set handler ro_popup->on_dialog_close for ro_popup->mo_dialogbox.

*       Görüntüle
        ro_popup->mo_dialogbox->set_visible( abap_true ).
        cl_gui_control=>set_focus( ro_popup->mo_dialogbox ).

        "http://www.alfayazilim.com/alfa-e-defter-destek?v=2.04
        ro_popup->mo_html->show_url( url = conv text255( url ) ).

      catch cx_root into data(lx_root).
        message lx_root type 'E'.
    endtry.

  endmethod.


  method on_dialog_close.

    mo_dialogbox->set_visible( abap_false ).

    mo_html->free( ).
    mo_dialogbox->free( ).

    clear mo_html.
    clear mo_dialogbox.

  endmethod.
endclass.
