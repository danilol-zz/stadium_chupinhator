class MongoConnection
  def self.client
    @client ||= lambda do
      Mongo::Logger.logger.level = Logger::WARN
      Mongo::Client.new(["localhost"], :database => "stadiums", :connect => :direct)
    end.call
  end
end
