class WeixinBot
  attr_accessor :uuid, :ticket, :lang, :scan
  attr_accessor :user_name, :sync_key

  WEIXIN_APPID = 'wx782c26e4c19acffb'
  ConfirmLoginError = Class.new StandardError

  def initialize(options={})
    options[:lang] ||= "en_US"
    HashWithIndifferentAccess.new(options).slice(:lang).each { |k, v| instance_variable_set("@#{k}", v) }
  end

  def run
    get_uuid
    show_login_qrcode
    confirm_login
    get_cookie
    get_init_info
    open_status_notify
    get_contact
    sync_message
  end

  def get_uuid
    params = {
      appid: WEIXIN_APPID,
      redirect_uri: "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage",
      fun: "new",
      lang: "en_US",
      _: Utility.current_timestamp("ms")
    }
    logger.info "uuid request: https://login.weixin.qq.com/jslogin?#{params.to_query}"
    resp = client.get("https://login.weixin.qq.com/jslogin?#{params.to_query}")
    logger.info "uuid response #{resp.status}: #{resp.body}"
    @uuid = resp.body.split('"')[-2]
  end

  def show_login_qrcode
    puts RQRCode::QRCode.new("https://login.weixin.qq.com/l/#{uuid}").as_ansi
  end

  def confirm_login
    loop do
      params = {
        uuid: uuid,
        tip: 0,
        _: Utility.current_timestamp
      }
      logger.info "login confirm request: https://login.weixin.qq.com/cgi-bin/mmwebwx-bin/login?#{params.to_query}"
      resp = client.get("https://login.weixin.qq.com/cgi-bin/mmwebwx-bin/login?#{params.to_query}")
      logger.info "login confirm resp #{resp.status}: #{resp.body}"
      resp_info = Utility.str_to_hash(resp.body)
      if resp_info["window.redirect_uri"].present?
        break Utility.parse_url_query(resp_info["window.redirect_uri"]).slice("ticket", "scan").each{|k, v| instance_variable_set("@#{k}", v) }
      elsif Integer(resp_info["window.code"]) >= 400
        raise ConfirmLoginError, resp.body
      else
        sleep 0.1
      end
    end
  end

  def get_cookie
    params = {
      ticket: ticket,
      uuid: uuid,
      lang: lang,
      scan: scan,
      fun: "new",
      version: "v2"
    }
    logger.info "cookie request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage?#{params.to_query}"
    resp = client.get("https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxnewloginpage?#{params.to_query}")
    logger.info "cookie response #{resp.status}: #{resp.body}"
    CookieStore.set(Utility.parse_xml(resp.body)["error"])
  end

  def get_init_info
    params = {
      r: Utility.current_timestamp,
      lang: lang,
      pass_ticket: CookieStore.pass_ticket
    }
    body = {
      BaseRequest: {
        Uin: CookieStore.wxuin,
        Sid: CookieStore.wxsid,
        Skey: CookieStore.skey,
        DeviseID: Utility.device_id
      }
    }
    logger.info "get init info resquest: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?#{params.to_query}"
    resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?#{params.to_query}", body.to_json
    logger.info "get init info response #{resp.status}: #{Utility.compact_json(resp.body)}"
    init_info = JSON.load(resp.body)
    @user_name = init_info["User"]["UserName"]
    @sync_key = init_info["SyncKey"]["List"].map{|h| "#{h['Key']}_#{h['Val']}" }.join("|")
  end

  def open_status_notify
    params = {
      lang: lang,
      pass_ticket: CookieStore.pass_ticket
    }
    body = {
      BaseRequest: {
        Uin: CookieStore.wxuin,
        Sid: CookieStore.wxsid,
        Skey: CookieStore.skey,
        DeviseID: Utility.device_id
      },
      Code: 3,
      FromUserName: user_name,
      ToUserName: user_name,
      ClientMsgId: Utility.current_timestamp
    }
    logger.info "open status notify request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxstatusnotify?#{params.to_query}"
    resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxstatusnotify?#{params.to_query}", body.to_json
    logger.info "open status notify response #{resp.status}: #{Utility.compact_json(resp.body)}"
  end

  def get_contact
    params = {
      seq: 0,
      pass_ticket: CookieStore.pass_ticket,
      skey: CookieStore.skey,
      r: Utility.current_timestamp
    }
    body = {
      BaseRequest: {
        Uin: CookieStore.wxuin,
        Sid: CookieStore.wxsid,
        Skey: CookieStore.skey,
        DeviseID: Utility.device_id
      }
    }
    logger.info "get contact request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxgetcontact?#{params.to_query}"
    resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxgetcontact?#{params.to_query}", body.to_json
    logger.info "get contact response #{resp.status}: #{Utility.compact_json(resp.body)}"
  end

  def sync_message
    loop do
      check_result = sync_check
      raise SyncCheckError, check_result.to_json unless check_result["retcode"] == "0"
      get_message if check_result["selector"].to_i > 0
    end
  end

  def sync_check
    params = {
      r: Utility.current_timestamp("ms"),
      sid: CookieStore.wxsid,
      uin: CookieStore.wxuin,
      deviceid: Utility.device_id,
      synckey: sync_key,
      _: Utility.current_timestamp("ms")
    }
    logger.info "sync check request: https://webpush.weixin.qq.com/cgi-bin/mmwebwx-bin/synccheck?#{params.to_query}"
    resp = client.get "https://webpush.wx.qq.com/cgi-bin/mmwebwx-bin/synccheck?#{params.to_query}"
    logger.info "sync check response #{resp.status}: #{resp.body}"
    Hash[*resp.body.split("=")[-1].gsub(/{|}|\"/, "").split(/:|,/)]
  end

  def get_message
    webwxsync_params = {
      sid: cookie_info["wxsid"],
      skey: cookie_info["skey"],
      lang: "en_US",
      pass_ticket: pass_ticket,
    }
    body = {
      BaseRequest: {
        DeviseID: Utility.device_id,
        Sid: cookie_info["wxsid"],
        Skey: cookie_info["skey"],
        Uin: cookie_info["wxuin"]
      },
      SyncKey: webwx_init_info["SyncKey"],
      rr: Time.now.to_i
    }
    webwxsync_resp = client.post("https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsync?#{webwxsync_params.to_query}"), body.to_json
    logger.info "webwxsync response #{webwxsync_resp.status}: #{webwxsync_resp.body}"
  end
end
