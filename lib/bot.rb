class WeixinBot
  attr_accessor :uuid, :ticket, :lang, :scan

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
    weixin_init
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

  def weixin_init
    logger.info "webwx init resquest: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?lang=en_US&pass_ticket=#{pass_ticket}"
    webwx_init_resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?r=#{Utility.current_timestamp}&lang=en_US&pass_ticket=#{pass_ticket}", {
      BaseRequest: {
        Uin: cookie_info["wxuin"],
        Sid: cookie_info["wxsid"],
        Skey: cookie_info["skey"],
        DeviseID: get_device_id
      }
    }.to_json
    logger.info "webwx init response #{webwx_init_resp.status}: #{webwx_init_resp.body}"
    webwx_init_info = JSON.load(webwx_init_resp.body)
  end

  def sync_message
    begin
      synccheck_params = {
        r: Utility.current_timestamp,
        skey: cookie_info["skey"],
        sid: cookie_info["wxsid"],
        uin: cookie_info["wxuin"],
        deviceid: get_device_id,
        synckey: webwx_init_info["SyncKey"]["List"].map{|h| "#{h['Key']}_#{h['Val']}" }.join("|")
      }
      synccheck_resp = client.get "https://webpush.weixin.qq.com/cgi-bin/mmwebwx-bin/synccheck?#{synccheck_params.to_query}"
      logger.info "synccheck response #{synccheck_resp.status}: #{synccheck_resp.body}"
    rescue => e
      logger.error "#{e.class.name}: #{e.message}"
      retry
    end

    webwxsync_params = {
      sid: cookie_info["wxsid"],
      skey: cookie_info["skey"],
      lang: "en_US",
      pass_ticket: pass_ticket,
    }
    webwxsync_resp = client.post("https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsync?#{webwxsync_params.to_query}"), {
      BaseRequest: {
        DeviseID: get_device_id,
        Sid: cookie_info["wxsid"],
        Skey: cookie_info["skey"],
        Uin: cookie_info["wxuin"]
      },
      SyncKey: webwx_init_info["SyncKey"],
      rr: Time.now.to_i
    }.to_json
    byebug
    logger.info "webwxsync response #{webwxsync_resp.status}: #{webwxsync_resp.body}"
  end
end
