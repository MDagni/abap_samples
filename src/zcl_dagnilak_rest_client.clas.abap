class zcl_dagnilak_rest_client definition
  public
  create private.

  public section.
    data mv_last_request  type string read-only.
    data mv_last_response type string read-only.

    class-methods clear_crlf
      changing
        !value type string.

    class-methods convert_to_json
      importing
        is_json_data   type data
        i_pretty_name  type /ui2/cl_json=>pretty_name_mode default /ui2/cl_json=>pretty_mode-camel_case
      returning
        value(rv_json) type string.

    class-methods create_by_destination
      importing
        !destination  type rfcdest
      returning
        value(result) type ref to zcl_dagnilak_rest_client.

    class-methods create_by_url
      importing
        url           type string
      returning
        value(result) type ref to zcl_dagnilak_rest_client.

    class-methods prepare_url
      importing
        i_url        type string
        it_params    type tihttpnvp
      returning
        value(e_url) type string.

    methods get
      importing
        i_url               type string
        i_use_authorization type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response_text     type string
        es_response_data    type data.

    class-methods parse_json
      importing
        i_json        type string
        i_pretty_name type /ui2/cl_json=>pretty_name_mode default /ui2/cl_json=>pretty_mode-camel_case
      exporting
        es_data       type data.

    methods post_form
      importing
        i_url               type string
        it_form_fields      type tihttpnvp optional
        i_use_authorization type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response_text     type string
        es_response_data    type data.

    methods post_json_data
      importing
        i_url               type string
        is_json_data        type data                           optional
        i_use_authorization type abap_bool                      default abap_true
        i_pretty_name       type /ui2/cl_json=>pretty_name_mode default /ui2/cl_json=>pretty_mode-camel_case
      exporting
        e_success           type abap_bool
        e_response_text     type string
        es_response_data    type data.

    methods post_string
      importing
        i_url               type string
        i_content_type      type string
        i_payload           type string
        i_use_authorization type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response_text     type string
        es_response_data    type data.

    methods put_form
      importing
        i_url               type string
        it_form_fields      type tihttpnvp optional
        i_use_authorization type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response_text     type string
        es_response_data    type data.

    methods put_json_data
      importing
        i_url               type string
        is_json_data        type data                           optional
        i_use_authorization type abap_bool                      default abap_true
        i_pretty_name       type /ui2/cl_json=>pretty_name_mode default /ui2/cl_json=>pretty_mode-camel_case
      exporting
        e_success           type abap_bool
        e_response_text     type string
        es_response_data    type data.

    methods put_string
      importing
        i_url               type string
        i_content_type      type string
        i_payload           type string
        i_use_authorization type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response_text     type string
        es_response_data    type data.

    methods set_authorization
      importing
        !name  type string default 'Authorization'
        !value type string.

    methods set_timeout
      importing
        i_timeout type i.

  private section.
    data mv_auth_name   type string.
    data mv_auth_value  type string.
    data mv_timeout     type i value 180 ##NO_TEXT.
    data mo_http_client type ref to if_http_client.

    class-methods parse_response
      importing
        io_response      type ref to if_rest_entity
      exporting
        e_response_text  type string
        es_response_data type data.

    methods call_rest_service
      importing
        io_rest_client      type ref to cl_rest_http_client
        i_url               type string
        i_method            type string
        io_payload          type ref to if_rest_entity optional
        i_use_authorization type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response_text     type string
        es_response_data    type data.
endclass.


class zcl_dagnilak_rest_client implementation.

  method call_rest_service.

    "Sonuç Hatalı olarak başla
    clear: e_success,
           e_response_text,
           es_response_data.

    try.
        "Servis elemanlarını yarat
        cl_http_utility=>set_request_uri( request = mo_http_client->request
                                          uri     = i_url ).

        "Authorization bilgisini ekle
        if i_use_authorization  = abap_true and
           mv_auth_value       is not initial.
          io_rest_client->if_rest_client~set_request_header( iv_name  = mv_auth_name
                                                             iv_value = mv_auth_value ).
        endif.

        "Çağrı yöntemine göre çağrıyı yap. Diğer yöntemler gerektikçe eklenebilir.
        case i_method.
          when if_rest_message=>gc_method_get.
            io_rest_client->if_rest_client~get( ).

          when if_rest_message=>gc_method_post.
            io_rest_client->if_rest_client~post( io_payload ).

          when if_rest_message=>gc_method_put.
            io_rest_client->if_rest_client~put( io_payload ).

          when if_rest_message=>gc_method_patch.
            "Patch metodu rest client'ta mevcut değil, enhancement ile eklenebilir
            "io_rest->patch( io_payload ).
            message a319(01) with 'PATCH METODU DESTEKLENMİYOR!'.

        endcase.

        "HTTP hatası dönmüşse exception çıkar. 403 gibi bir hata gelirse rest client'tan exception
        "dönmüyor.
        if io_rest_client->if_rest_client~get_status( ) <> 200.
          raise exception type cx_rest_client_exception
            exporting
              textid = cx_rest_client_exception=>http_client_comm_failure.
        endif.

        "Çağrı başarılı ise servisten dönen bilgiyi al
        e_success = abap_true.

        "Dönen cevabı Abap verisine dönüştür
        if es_response_data is supplied.
          parse_response( exporting io_response      = io_rest_client->if_rest_client~get_response_entity( )
                          importing e_response_text  = e_response_text
                                    es_response_data = es_response_data ).
        else.
          e_response_text = io_rest_client->if_rest_client~get_response_entity( )->get_string_data( ).
        endif.

      catch cx_rest_client_exception into data(lx_rest).
        "Çağrı sırasında hata çıkarsa
        e_success = abap_false.

        "HTTP hatası dönmüşse onu al
        data(lv_http_status) = io_rest_client->if_rest_client~get_status( ).
        mo_http_client->get_last_error( importing message = e_response_text ).

        if e_response_text is not initial.
          e_response_text = |HTTP { lv_http_status } - { e_response_text }|.
        else.
          "Sunucudan cevap olarak hata mesajı döndüyse onu al
          parse_response( exporting io_response      = io_rest_client->if_rest_client~get_response_entity( )
                          importing e_response_text  = e_response_text
                                    es_response_data = es_response_data ).
        endif.

        "Sunucudan bir şey dönmediyse exception metnini al
        if e_response_text is initial.
          e_response_text = lx_rest->get_text( ).
        endif.

      catch cx_root into data(lx_root) ##CATCH_ALL.
        "Başka bir hata çıkarsa
        e_success = abap_false.
        e_response_text = lx_root->get_text( ).
    endtry.

    "debug için
    mv_last_request  = cl_bcs_convert=>xstring_to_string( iv_xstr = mo_http_client->request->to_xstring( )
                                                          iv_cp   = '1100' ).

    mv_last_response = cl_bcs_convert=>xstring_to_string( iv_xstr = mo_http_client->response->get_raw_message( )
                                                          iv_cp   = '1100' ).

    if io_rest_client is bound.
      io_rest_client->if_rest_client~close( ).
    endif.

  endmethod.


  method clear_crlf.

    replace all occurrences of cl_abap_char_utilities=>cr_lf   in value with ` `.
    replace all occurrences of cl_abap_char_utilities=>newline in value with ` `.

  endmethod.


  method convert_to_json.

    rv_json = /ui2/cl_json=>serialize( data        = is_json_data
                                       compress    = abap_false
                                       pretty_name = i_pretty_name ).

  endmethod.


  method create_by_destination.

    result = new #( ).

    cl_http_client=>create_by_destination( exporting  destination              = destination
                                           importing  client                   = result->mo_http_client
                                           exceptions argument_not_found       = 1
                                                      destination_not_found    = 2
                                                      destination_no_authority = 3
                                                      plugin_not_active        = 4
                                                      internal_error           = 5
                                                      others                   = 6 ).

    if sy-subrc <> 0.
      message id sy-msgid type sy-msgty number sy-msgno
              with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    endif.

    result->mo_http_client->propertytype_logon_popup   = if_http_client=>co_disabled.
    result->mo_http_client->propertytype_accept_cookie = if_http_client=>co_enabled.

  endmethod.


  method create_by_url.

    result = new #( ).

    cl_http_client=>create_by_url( exporting  url                = url
                                   importing  client             = result->mo_http_client
                                   exceptions argument_not_found = 1
                                              plugin_not_active  = 2
                                              internal_error     = 3
                                              others             = 4 ).

    if sy-subrc <> 0.
      message id sy-msgid type sy-msgty number sy-msgno
              with sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4.
    endif.

    result->mo_http_client->propertytype_logon_popup   = if_http_client=>co_disabled.
    result->mo_http_client->propertytype_accept_cookie = if_http_client=>co_enabled.

  endmethod.


  method get.

    data(lo_rest_client) = new cl_rest_http_client( mo_http_client ).

    call_rest_service( exporting io_rest_client      = lo_rest_client
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_get
                                 i_use_authorization = i_use_authorization
                       importing e_success           = e_success
                                 e_response_text     = e_response_text
                                 es_response_data    = es_response_data ).

  endmethod.


  method parse_json.

    /ui2/cl_json=>deserialize( exporting json        = i_json
                                         pretty_name = i_pretty_name
                               changing  data        = es_data ).
  endmethod.


  method parse_response.

    clear es_response_data.

    e_response_text = io_response->get_string_data( ).

    io_response->get_content_type( importing ev_media_type = data(lv_media_type) ).

    case lv_media_type.
      when if_rest_media_type=>gc_appl_json.
        parse_json( exporting i_json  = e_response_text
                    importing es_data = es_response_data ).
    endcase.

  endmethod.


  method post_form.

    data(lo_rest_client) = new cl_rest_http_client( mo_http_client ).

    data(lo_payload) = lo_rest_client->if_rest_client~create_request_entity( ).

    data(lo_form) = new cl_rest_form_data( ).
    lo_form->set_form_fields( it_form_fields ).
    lo_form->write_to( lo_payload ).

    call_rest_service( exporting io_rest_client      = lo_rest_client
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_post
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                       importing e_success           = e_success
                                 e_response_text     = e_response_text
                                 es_response_data    = es_response_data ).

  endmethod.


  method post_json_data.

    data(lo_rest_client) = new cl_rest_http_client( mo_http_client ).

    data(lo_payload) = lo_rest_client->if_rest_client~create_request_entity( ).

    data(lv_json) = convert_to_json( is_json_data  = is_json_data
                                     i_pretty_name = i_pretty_name ).

    lo_payload->set_content_type( if_rest_media_type=>gc_appl_json ).
    lo_payload->set_string_data( lv_json ).

    call_rest_service( exporting io_rest_client      = lo_rest_client
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_post
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                       importing e_success           = e_success
                                 e_response_text     = e_response_text
                                 es_response_data    = es_response_data ).

  endmethod.


  method post_string.

    data(lo_rest_client) = new cl_rest_http_client( mo_http_client ).

    data(lo_payload) = lo_rest_client->if_rest_client~create_request_entity( ).

    lo_payload->set_content_type( i_content_type ).   "if_rest_media_type=>gc_appl_json
    lo_payload->set_string_data( i_payload ).

    call_rest_service( exporting io_rest_client      = lo_rest_client
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_post
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                       importing e_success           = e_success
                                 e_response_text     = e_response_text
                                 es_response_data    = es_response_data ).

  endmethod.


  method prepare_url.

    e_url = i_url.

    loop at it_params assigning field-symbol(<ls_param>).
      replace all occurrences of <ls_param>-name in e_url with <ls_param>-value.
    endloop.

  endmethod.


  method put_form.

    data(lo_rest_client) = new cl_rest_http_client( mo_http_client ).

    data(lo_payload) = lo_rest_client->if_rest_client~create_request_entity( ).

    data(lo_form) = new cl_rest_form_data( ).
    lo_form->set_form_fields( it_form_fields ).
    lo_form->write_to( lo_payload ).

    call_rest_service( exporting io_rest_client      = lo_rest_client
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_put
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                       importing e_success           = e_success
                                 e_response_text     = e_response_text
                                 es_response_data    = es_response_data ).

  endmethod.


  method put_json_data.

    data(lo_rest_client) = new cl_rest_http_client( mo_http_client ).

    data(lo_payload) = lo_rest_client->if_rest_client~create_request_entity( ).

    data(lv_json) = convert_to_json( is_json_data  = is_json_data
                                     i_pretty_name = i_pretty_name ).
    lo_payload->set_content_type( if_rest_media_type=>gc_appl_json ).
    lo_payload->set_string_data( lv_json ).

    call_rest_service( exporting io_rest_client      = lo_rest_client
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_put
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                       importing e_success           = e_success
                                 e_response_text     = e_response_text
                                 es_response_data    = es_response_data ).

  endmethod.


  method put_string.

    data(lo_rest_client) = new cl_rest_http_client( mo_http_client ).

    data(lo_payload) = lo_rest_client->if_rest_client~create_request_entity( ).

    lo_payload->set_content_type( i_content_type ).   "if_rest_media_type=>gc_appl_json
    lo_payload->set_string_data( i_payload ).

    call_rest_service( exporting io_rest_client      = lo_rest_client
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_put
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                       importing e_success           = e_success
                                 e_response_text     = e_response_text
                                 es_response_data    = es_response_data ).

  endmethod.


  method set_authorization.

    mv_auth_name = name.
    mv_auth_value = value.

  endmethod.


  method set_timeout.

    mv_timeout = i_timeout.

  endmethod.

endclass.
