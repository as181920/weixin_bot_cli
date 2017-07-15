module WeixinBotCli
  class MessageHandler
    attr_reader :bot

    def initialize(bot)
      @bot = bot
    end

    def handle(msg, bot)
      sender, content = parse_msg_content(msg)
      msg_info = {
        MsgId: msg["MsgId"],
        FromUserName: bot.contact_name_pairs[msg["FromUserName"]] || msg["FromUserName"],
        ToUserName: bot.contact_name_pairs[msg["ToUserName"]] || msg["ToUserName"],
        MsgType: msg["MsgType"],
        CreateTime: msg["CreateTime"],
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
      def parse_msg_content(msg)
        content = msg["Content"]
        if content =~ /^@\w{10,99}:<br\/>/
          sender, real_content = content.split(":<br/>", 2)
          return [(bot.contact_name_pairs[sender] || sender), format_content(real_content)]
        else
          return [bot.contact_name_pairs[msg["FromUserName"]], format_content(content)]
        end
      end

      def format_content(content)
        content.to_s.gsub("<br/>", "\n")
      end
  end
end
