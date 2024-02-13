require "http/server"
require "http/client"
require "sqlite3"
require "json"

MIHOMO_API_BASE = "https://api.mihomo.me"
PUNKLORDE_DB_URL = "sqlite3://./punklorde.db"

# refactor into class
DB_CHANNEL = Channel(Array(DB::Any)).new
spawn do
  DB.open PUNKLORDE_DB_URL do |db|
    upsert_statement = db.build "
      INSERT INTO characters (player_uid, character_id, name,
                              hp, atk, def, spd, crit_rate, crit_dmg, err, ehr, effect_res, break_effect, 
                              fire_dmg_boost, ice_dmg_boost, imaginary_dmg_boost, quantum_dmg_boost, lightning_dmg_boost,
                              physical_dmg_boost, wind_dmg_boost, crit_value)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21)
      ON CONFLICT (player_uid, character_id)
      DO UPDATE SET
        hp = excluded.hp,
        atk = excluded.atk,
        def = excluded.def,
        spd = excluded.spd,
        crit_rate = excluded.crit_rate,
        crit_dmg = excluded.crit_dmg,
        err = excluded.err,
        ehr = excluded.ehr,
        effect_res = excluded.effect_res,
        break_effect = excluded.break_effect,
        fire_dmg_boost = excluded.fire_dmg_boost,
        ice_dmg_boost = excluded.ice_dmg_boost,
        imaginary_dmg_boost = excluded.imaginary_dmg_boost,
        quantum_dmg_boost = excluded.quantum_dmg_boost,
        lightning_dmg_boost = excluded.lightning_dmg_boost,
        physical_dmg_boost = excluded.physical_dmg_boost,
        wind_dmg_boost = excluded.wind_dmg_boost,
        crit_value = excluded.crit_value;
    "
    
    loop do
      row = DB_CHANNEL.receive
      upsert_statement.exec(args: row)
    end
  end
end

ATTRIBUTE_KEYS = [
  "hp",
  "atk",
  "def",
  "spd",
  "crit_rate",
  "crit_dmg",
  "sp_rate",      # err
  "effect_hit",   # ehr
  "effect_res",
  "break_dmg",    # break_effect
  "fire_dmg",
  "ice_dmg",
  "imaginary_dmg",
  "quantum_dmg",
  "lightning_dmg",
  "physical_dmg",
  "wind_dmg",
]

# TODO struct for json
def upsert_profile(uid : String, info : String)
  info = JSON.parse(info)
  info["characters"].as_a.each do |char|

    row = [] of DB::Any
    row << uid

    char_id = char["id"].as_s.to_i
    row << char_id

    # check if trailblazer
    if char_id > 8000
      path = char["path"]["name"]
      row << "Trailblazer - #{path}"
    else
      row << char["name"].as_s
    end
    
    # base attributes + additional stats from relics, talents, LC, etc
    char_attrs = Hash(String, Float64).new
    (char["attributes"].as_a + char["additions"].as_a).each do |attr|
      key = attr["field"].as_s
      char_attrs[key] = char_attrs.fetch(key, 0.0) + attr["value"].as_f
    end

    ATTRIBUTE_KEYS.each do |attr|
      row << char_attrs.fetch(attr, 0.0)
    end

    # calculate crit value
    total_cv = 0.0
    char["relics"].as_a.each do |relic|
      sub_affixes = relic["sub_affix"].as_a
      
      sub_cr = sub_affixes.find { |attr| attr["field"] == "crit_rate" }
      sub_cr = sub_cr.nil? ? 0.0 : sub_cr["value"].as_f

      sub_cd = sub_affixes.find { |attr| attr["field"] == "crit_dmg" }
      sub_cd = sub_cd.nil? ? 0.0 : sub_cd["value"].as_f
      
      main_attr = relic["main_affix"]["field"]
      total_cv += if main_attr == "crit_dmg"
                    sub_cr * 2
                  elsif main_attr == "crit_rate"
                    sub_cd          
                  else
                    2 * sub_cr + sub_cd
                  end
    end
    row << total_cv

    DB_CHANNEL.send(row)
  end
end

mihomo_uri = URI.parse(MIHOMO_API_BASE)
mihomo_client = HTTP::Client.new(mihomo_uri)

server = HTTP::Server.new([
  HTTP::ErrorHandler.new,
  HTTP::LogHandler.new,
  HTTP::CompressHandler.new,
]) do |ctx|
  params = ctx.request.query_params

  case ctx.request.path
  when "/api/characters"
    uid = params["uid"]?
    next ctx.response.respond_with_status(400, "no uid supplied") if uid.nil?
    
    mihomo_client.get "/sr_info_parsed/#{uid}?lang=en" do |res|
      next ctx.response.respond_with_status(404, "invalid uid") unless res.success?
      
      body = res.body_io.gets_to_end
      upsert_profile(uid, body)
      ctx.response.content_type = "application/json"
      ctx.response << body
    end
  when "/api/top"
    sort = params["sort"]?
    next ctx.response.respond_with_status(400, "no sort key(s) supplied") if sort.nil?
    
    sort_keys = sort.split(",")
    
  else
    ctx.response.respond_with_status(404, "not found")
  end
end

address = server.bind_tcp 8080
puts "Listening on http://#{address}"
server.listen
