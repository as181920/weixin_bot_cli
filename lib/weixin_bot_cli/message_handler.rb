module WeixinBotCli
  class MessageHandler
    attr_reader :bot

    def initialize(bot)
      @bot = bot
    end

    def handle(msg, bot)
      sender, content = parse_msg_content(msg["Content"])
      msg_info = {
        MsgId: msg["MsgId"],
        FromUserName: bot.full_contact_info_hash[msg["FromUserName"]] || msg["FromUserName"],
        ToUserName: bot.full_contact_info_hash[msg["ToUserName"]] || msg["ToUserName"],
        MsgType: msg["MsgType"],
        Sender: sender,
        Content: content
      }
      puts "Message => #{msg_info.to_json}"
      STDOUT.flush
      if content =~ /@#{bot.current_user["NickName"]}/
        return {Content: "@#{sender} 哼", Type: 1}
      end
    end

    private
      def parse_msg_content(content)
        if content =~ /^@\w{10,99}:<br\/>/
          sender, real_content = content.split(":<br/>", 2)
          return [(bot.full_contact_info_hash[sender] || sender), format_content(real_content)]
        else
          return [bot.current_user["NickName"], format_content(content)]
        end
      end

      def format_content(content)
        content.to_s.gsub("<br/>", "\n")
      end
  end
end
