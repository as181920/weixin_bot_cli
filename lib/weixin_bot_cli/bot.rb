module WeixinBotCli
  class Bot
    attr_accessor :client, :logger, :device_id
    attr_accessor :uuid, :ticket, :scan, :lang
    attr_accessor :wxuin, :wxsid, :skey, :pass_ticket
    attr_accessor :bot_user_name, :sync_key

    WEIXIN_APPID = 'wx782c26e4c19acffb'
    ConfirmLoginError = Class.new StandardError

    def initialize(options={})
      @client = Faraday.new do |builder|
        builder.use :cookie_jar
        builder.adapter Faraday.default_adapter
      end
      @logger = Logger.new STDOUT
      @device_id = "e#{Random.rand(10**15).to_s.rjust(15,'0')}"

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
        lang: lang,
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
      HashWithIndifferentAccess.new(Utility.parse_xml(resp.body)["error"]).slice(:wxuin, :wxsid, :skey, :pass_ticket).each{ |k, v| instance_variable_set "@#{k}", v }
    end

    def get_init_info
      params = {
        r: Utility.current_timestamp,
        lang: lang,
        pass_ticket: pass_ticket
      }
      body = {
        BaseRequest: base_request
      }
      logger.info "get init info resquest: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?#{params.to_query}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxinit?#{params.to_query}", body.to_json
      logger.info "get init info response #{resp.status}: #{JSON.load(resp.body).slice('BaseResponse', 'Count', 'User').to_json}"
      init_info = JSON.load(resp.body)
      @bot_user_name = init_info["User"]["UserName"]
      @sync_key = init_info["SyncKey"]
    end

    def open_status_notify
      params = {
        lang: lang,
        pass_ticket: pass_ticket
      }
      body = {
        BaseRequest: base_request,
        Code: 3,
        FromUserName: bot_user_name,
        ToUserName: bot_user_name,
        ClientMsgId: Utility.current_timestamp
      }
      logger.info "open status notify request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxstatusnotify?#{params.to_query}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxstatusnotify?#{params.to_query}", body.to_json
      logger.info "open status notify response #{resp.status}: #{Utility.compact_json(resp.body)}"
    end

    def get_contact
      params = {
        seq: 0,
        pass_ticket: pass_ticket,
        skey: skey,
        r: Utility.current_timestamp
      }
      body = {
        BaseRequest: base_request
      }
      logger.info "get contact request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxgetcontact?#{params.to_query}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxgetcontact?#{params.to_query}", body.to_json
      logger.info "get contact response #{resp.status}: #{JSON.load(resp.body).slice('BaseResponse', 'MemberCount').to_json}"
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
        sid: wxsid,
        uin: wxuin,
        deviceid: device_id,
        synckey: synckey_to_str(sync_key),
        _: Utility.current_timestamp("ms")
      }
      logger.info "sync check request: https://webpush.weixin.qq.com/cgi-bin/mmwebwx-bin/synccheck?#{params.to_query}"
      resp = client.get "https://webpush.wx.qq.com/cgi-bin/mmwebwx-bin/synccheck?#{params.to_query}"
      logger.info "sync check response #{resp.status}: #{resp.body}"
      Hash[*resp.body.split("=")[-1].gsub(/{|}|\"/, "").split(/:|,/)]
    end

    def get_message
      params = {
        sid: wxsid,
        skey: skey,
        pass_ticket: pass_ticket,
        lang: lang
      }
      body = {
        BaseRequest: base_request,
        SyncKey: sync_key,
        rr: ~Utility.current_timestamp
      }
      logger.info "get message request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsync?#{params.to_query}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsync?#{params.to_query}", body.to_json
      logger.info "get message response: #{resp.status}: #{JSON.load(resp.body).slice('BaseResponse', 'AddMsgCount', 'AddMsgList').to_json}"
      resp_info = JSON.load(resp.body)
      @sync_key = resp_info["SyncKey"]
      resp_info['AddMsgList'].each do |msg|
        reply = Hash(MessageHandler.reply(msg))
        client_msg_id = "#{Time.now.to_i * 10000}#{Random.rand(1000..9999)}"
        send_message({FromUserName: bot_user_name, ToUserName: msg["FromUserName"], LocalID: client_msg_id, ClientMsgId: client_msg_id}.merge(reply)) if reply.present?
      end
    end

    def send_message(msg)
      params = {
        lang: lang,
        pass_ticket: pass_ticket
      }
      body = {
        BaseRequest: base_request,
        Msg: msg
      }
      logger.info "send msg request: https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsendmsg?#{params.to_query}"
      resp = client.post "https://wx.qq.com/cgi-bin/mmwebwx-bin/webwxsendmsg?#{params.to_query}", body.to_json
      logger.info "send msg response #{resp.status}: #{Utility.compact_json(resp.body)}"
    end

    private
    def synckey_to_str(sync_key_hash)
      sync_key_hash["List"].map{|h| "#{h['Key']}_#{h['Val']}" }.join("|")
    end

    def base_request
      { Uin: wxuin, Sid: wxsid, Skey: skey, DeviceID: device_id }
    end
  end
end
