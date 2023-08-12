class zcl_dagnilak_rest_services definition
  public
  final
  create public.

  public section.
    data mv_access_token  type string read-only.
    data mv_api_key       type string read-only.
    data mv_last_request  type string read-only.
    data mv_last_response type string read-only.

    methods constructor
      importing
        !destination type rfcdest.

    methods convert_crlf
      changing
        !value type string.

    methods get
      importing
        i_url               type string
        i_use_authorization type abap_bool default abap_true
        i_use_api_key       type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response          type string
        es_response_data    type data.

    methods post_form
      importing
        i_url               type string
        it_form_fields      type tihttpnvp optional
        i_use_authorization type abap_bool default abap_true
        i_use_api_key       type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response          type string
        es_response_data    type data.

    methods post_json_data
      importing
        i_url               type string
        is_json_data        type data      optional
        i_use_authorization type abap_bool default abap_true
        i_use_api_key       type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response          type string
        es_response_data    type data.

    methods post_payload
      importing
        i_url               type string
        i_content_type      type string    default if_rest_media_type=>gc_text_plain
        i_payload           type string
        i_use_authorization type abap_bool default abap_true
        i_use_api_key       type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response          type string
        es_response_data    type data.

    methods prepare_url
      importing
        i_url        type string
        it_params    type tihttpnvp
      returning
        value(e_url) type string.

    methods put_form
      importing
        i_url               type string
        it_form_fields      type tihttpnvp optional
        i_use_authorization type abap_bool default abap_true
        i_use_api_key       type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response          type string
        es_response_data    type data.

    methods put_json_data
      importing
        i_url               type string
        is_json_data        type data      optional
        i_use_authorization type abap_bool default abap_true
        i_use_api_key       type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response          type string
        es_response_data    type data.

    methods put_payload
      importing
        i_url               type string
        i_content_type      type string    default if_rest_media_type=>gc_text_plain
        i_payload           type string
        i_use_authorization type abap_bool default abap_true
        i_use_api_key       type abap_bool default abap_true
      exporting
        e_success           type abap_bool
        e_response          type string
        es_response_data    type data.

    methods set_timeout
      importing
        i_timeout type i.

  private section.
    data mv_timeout type i value 180 ##NO_TEXT.
    data mo_http    type ref to if_http_client.

    methods call_rest_service
      importing
        io_rest             type ref to cl_rest_http_client
        i_url               type string
        i_method            type string
        io_payload          type ref to if_rest_entity optional
        i_use_authorization type abap_bool             default abap_true
        i_use_api_key       type abap_bool             default abap_true
      exporting
        e_success           type abap_bool
        e_response          type string
        es_response_data    type data.

    methods parse_response
      importing
        io_response      type ref to if_rest_entity
      exporting
        e_response       type string
        es_response_data type data.
endclass.


class zcl_dagnilak_rest_services implementation.

  method call_rest_service.

    " Sonuç Hatalı olarak başla
    clear: e_success, e_response, es_response_data.

    try.
        "Servis elemanlarını yarat
        cl_http_utility=>set_request_uri( request = mo_http->request
                                          uri     = i_url ).

        "Authorization bilgisini ekle
        if i_use_authorization  = abap_true and
           mv_access_token     is not initial.
          io_rest->if_rest_client~set_request_header( iv_name  = 'Authorization'
                                                      iv_value = |Bearer { mv_access_token }| ).
        endif.

        if i_use_api_key  = abap_true and
           mv_api_key    is not initial.
          io_rest->if_rest_client~set_request_header( iv_name  = 'X-Api-Key'
                                                      iv_value = mv_api_key ).
        endif.

        "Çağrı yöntemine göre çağrıyı yap. Diğer yöntemler gerektikçe eklenebilir.
        case i_method.
          when if_rest_message=>gc_method_get.
            io_rest->if_rest_client~get( ).

          when if_rest_message=>gc_method_post.
            io_rest->if_rest_client~post( io_payload ).

          when if_rest_message=>gc_method_put.
            io_rest->if_rest_client~put( io_payload ).

          when if_rest_message=>gc_method_patch.
            "Patch metodu rest client'ta mevcut değil, enhancement ile eklenebilir
            "io_rest->if_rest_client~patch( io_payload ).
            message a319(01) with 'PATCH METODU DESTEKLENMİYOR!'.

        endcase.

        "HTTP hatası dönmüşse exception çıkar. 403 gibi bir hata gelirse rest client'tan exception
        "dönmüyor.
        if io_rest->if_rest_client~get_status( ) <> 200.
          raise exception type cx_rest_client_exception
            exporting
              textid = cx_rest_client_exception=>http_client_comm_failure.
        endif.

        "Çağrı başarılı ise servisten dönen bilgiyi al
        e_success = abap_true.

        "Dönen cevabı Abap verisine dönüştür
        if es_response_data is supplied.
          parse_response( exporting io_response      = io_rest->if_rest_client~get_response_entity( )
                          importing e_response       = e_response
                                    es_response_data = es_response_data ).
        endif.

      catch cx_rest_client_exception into data(lx_rest).
        "Çağrı sırasında hata çıkarsa
        e_success = abap_false.

        "HTTP hatası dönmüşse onu al
        data(lv_http_status) = io_rest->if_rest_client~get_status( ).
        mo_http->get_last_error( importing message = e_response ).

        if e_response is initial.
          "Sunucudan cevap olarak hata mesajı döndüyse onu al
          parse_response( exporting io_response      = io_rest->if_rest_client~get_response_entity( )
                          importing e_response       = e_response
                                    es_response_data = es_response_data ).

          convert_crlf( changing value = e_response ).
        endif.

        e_response = |HTTP { lv_http_status } - { e_response }|.

        "Yoksa exception metnini al
        if e_response is initial.
          e_response = lx_rest->get_text( ).
        endif.

      catch cx_root into data(lx_root) ##CATCH_ALL.
        "Başka bir hata çıkarsa
        e_success = abap_false.
        e_response = lx_root->get_text( ).
    endtry.

    "debug için
    mv_last_request  = cl_bcs_convert=>xstring_to_string( iv_xstr = mo_http->request->to_xstring( )
                                                          iv_cp   = '1100' ).

    mv_last_response = cl_bcs_convert=>xstring_to_string( iv_xstr = mo_http->response->get_raw_message( )
                                                          iv_cp   = '1100' ).

    if io_rest is bound.
      io_rest->if_rest_client~close( ).
    endif.

  endmethod.


  method constructor.

    cl_http_client=>create_by_destination( exporting  destination              = destination
                                           importing  client                   = mo_http
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

    mo_http->propertytype_logon_popup   = if_http_client=>co_disabled.
    mo_http->propertytype_accept_cookie = if_http_client=>co_enabled.

    "TEST!!!
    mv_api_key = `669fb4a711a14429b278cc0c22b6f6ec`.

  endmethod.


  method convert_crlf.

    replace all occurrences of cl_abap_char_utilities=>cr_lf   in value with ` `.
    replace all occurrences of cl_abap_char_utilities=>newline in value with ` `.

  endmethod.


  method get.

    data(lo_rest) = new cl_rest_http_client( mo_http ).

    call_rest_service( exporting io_rest             = lo_rest
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_get
                                 i_use_authorization = i_use_authorization
                                 i_use_api_key       = i_use_api_key
                       importing e_success           = e_success
                                 e_response          = e_response
                                 es_response_data    = es_response_data ).

  endmethod.


  method parse_response.

    clear es_response_data.

    e_response = io_response->get_string_data( ).

    io_response->get_content_type( importing ev_media_type = data(lv_media_type) ).

    case lv_media_type.
      when if_rest_media_type=>gc_appl_json.
        /ui2/cl_json=>deserialize( exporting json        = e_response
                                             pretty_name = /ui2/cl_json=>pretty_mode-camel_case
                                   changing  data        = es_response_data ).
    endcase.

  endmethod.


  method post_form.

    data(lo_rest) = new cl_rest_http_client( mo_http ).

    data(lo_payload) = lo_rest->if_rest_client~create_request_entity( ).

    data(lo_form) = new cl_rest_form_data( ).
    lo_form->set_form_fields( it_form_fields ).
    lo_form->write_to( lo_payload ).

    call_rest_service( exporting io_rest             = lo_rest
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_post
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                                 i_use_api_key       = i_use_api_key
                       importing e_success           = e_success
                                 e_response          = e_response
                                 es_response_data    = es_response_data ).

  endmethod.


  method post_json_data.

    data(lo_rest) = new cl_rest_http_client( mo_http ).

    data(lo_payload) = lo_rest->if_rest_client~create_request_entity( ).

    data(lv_data_to_send) = /ui2/cl_json=>serialize( data        = is_json_data
                                                     compress    = abap_false
                                                     pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    lo_payload->set_content_type( if_rest_media_type=>gc_appl_json ).
    lo_payload->set_string_data( lv_data_to_send ).

    call_rest_service( exporting io_rest             = lo_rest
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_post
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                                 i_use_api_key       = i_use_api_key
                       importing e_success           = e_success
                                 e_response          = e_response
                                 es_response_data    = es_response_data ).

  endmethod.


  method post_payload.

    data(lo_rest) = new cl_rest_http_client( mo_http ).

    data(lo_payload) = lo_rest->if_rest_client~create_request_entity( ).

    lo_payload->set_content_type( i_content_type ).
    lo_payload->set_string_data( i_payload ).

    call_rest_service( exporting io_rest             = lo_rest
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_post
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                                 i_use_api_key       = i_use_api_key
                       importing e_success           = e_success
                                 e_response          = e_response
                                 es_response_data    = es_response_data ).

  endmethod.


  method prepare_url.

    e_url = i_url.

    loop at it_params assigning field-symbol(<ls_param>).
      replace <ls_param>-name in e_url with <ls_param>-value.
    endloop.

  endmethod.


  method put_form.

    data(lo_rest) = new cl_rest_http_client( mo_http ).

    data(lo_payload) = lo_rest->if_rest_client~create_request_entity( ).

    data(lo_form) = new cl_rest_form_data( ).
    lo_form->set_form_fields( it_form_fields ).
    lo_form->write_to( lo_payload ).

    call_rest_service( exporting io_rest             = lo_rest
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_put
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                                 i_use_api_key       = i_use_api_key
                       importing e_success           = e_success
                                 e_response          = e_response
                                 es_response_data    = es_response_data ).

  endmethod.


  method put_json_data.

    data(lo_rest) = new cl_rest_http_client( mo_http ).

    data(lo_payload) = lo_rest->if_rest_client~create_request_entity( ).

    data(lv_data_to_send) = /ui2/cl_json=>serialize( data        = is_json_data
                                                     compress    = abap_false
                                                     pretty_name = /ui2/cl_json=>pretty_mode-camel_case ).

    lo_payload->set_content_type( if_rest_media_type=>gc_appl_json ).
    lo_payload->set_string_data( lv_data_to_send ).

    call_rest_service( exporting io_rest             = lo_rest
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_put
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                                 i_use_api_key       = i_use_api_key
                       importing e_success           = e_success
                                 e_response          = e_response
                                 es_response_data    = es_response_data ).

  endmethod.


  method put_payload.

    data(lo_rest) = new cl_rest_http_client( mo_http ).

    data(lo_payload) = lo_rest->if_rest_client~create_request_entity( ).

    lo_payload->set_content_type( i_content_type ).
    lo_payload->set_string_data( i_payload ).

    call_rest_service( exporting io_rest             = lo_rest
                                 i_url               = i_url
                                 i_method            = if_rest_message=>gc_method_put
                                 io_payload          = lo_payload
                                 i_use_authorization = i_use_authorization
                                 i_use_api_key       = i_use_api_key
                       importing e_success           = e_success
                                 e_response          = e_response
                                 es_response_data    = es_response_data ).

  endmethod.


  method set_timeout.

    mv_timeout = i_timeout.

  endmethod.

endclass.
