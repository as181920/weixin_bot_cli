module WeixinBotCli
  class UserHandler
    attr_reader :bot

    def initialize(bot)
      @bot = bot
    end

    def handle(user)
      puts "User => #{user.slice('Uin', 'UserName', 'NickName', 'Signature').to_json}"
      STDOUT.flush
    end
  end
end
