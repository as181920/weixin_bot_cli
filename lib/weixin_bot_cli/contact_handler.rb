module WeixinBotCli
  class ContactHandler
    attr_reader :bot

    def initialize(bot)
      @bot = bot
    end

    def handle(contact)
      puts "Contact => #{contact.slice('UserName', 'NickName', 'Signature', 'VerifyFlag', 'Topic', 'Status').to_json}"
      STDOUT.flush
    end
  end
end

