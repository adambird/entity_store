module Sequel
  def self.parse_json(json)
    JSON.parse(json, create_additions: true)
  end
end
