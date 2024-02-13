CREATE TABLE IF NOT EXISTS characters (
  player_uid    INT,
  character_id  INT,
  name          VARCHAR(64),

  -- Other data (eidolons, relics, LC) are fetched on each request. This DB is just for global rankings.
  hp                    INT,
  atk                   INT,
  def                   INT,
  spd                   REAL,
  crit_rate             REAL,
  crit_dmg              REAL,
  err                   REAL,
  ehr                   REAL,
  effect_res            REAL,
  break_effect          REAL,
  fire_dmg_boost        REAL,
  ice_dmg_boost         REAL,
  imaginary_dmg_boost   REAL,
  quantum_dmg_boost     REAL,
  lightning_dmg_boost   REAL,
  physical_dmg_boost    REAL,
  wind_dmg_boost        REAL,

  -- Derived stats
  crit_value            REAL,

  PRIMARY KEY (player_uid, character_id)
);
