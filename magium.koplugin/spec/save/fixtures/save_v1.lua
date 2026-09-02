-- save_v1.lua — a frozen golden of the on-disk save shape as of Phase V
-- (2026-09-04). Phase V.5, item 4: a tripwire for the day the save format
-- changes and an old save silently fails to load. `schema_compat_spec.lua`
-- loads this through the REAL SaveManager and asserts every field lands.
--
-- Shape (see save/manager.lua):
--   state blob  (the `writer` adapter — magium/state):
--     { currentState = <v_* map, no v_ac_*>,
--       achievements = <v_ac_* map, "1" unseen / "2" seen>,
--       checkpoint   = { state = <currentState snapshot>, date = <os.time> } | nil,
--       slots        = <unused; legacy field, preserved untouched> }
--   per-slot blob  (the `slotstore` adapter — magium/slots/NN.blob):
--     { state = <currentState snapshot>, date = <os.time>, name = <string> }
--
-- Values are representative of a real mid-Book-2 save (hand-authored, not a
-- literal dump — depth doesn't matter, field coverage does). If you change the
-- format, add save_v2.lua next to this and keep this test loading BOTH.
return {
  state = {
    currentState = {
      v_current_scene = "B2-Ch04a-Introduction",
      v_gold = "63",
      v_strength = "3", v_agility = "2", v_perception = "4",
      v_combat_technique = "2", v_premonition = "1",
      v_baria_relationship = "3",
      v_ch1_show_yourself = "1",
      v_maximized_stats_used = "0",
    },
    achievements = {
      v_ac_ch1_coward = "2",   -- earned + seen
      v_ac_ch1_die = "2",
      v_ac_ch2_baria = "1",    -- earned, not yet shown
    },
    checkpoint = {
      state = {
        v_current_scene = "B2-Ch01a-Intro",
        v_gold = "40",
        v_strength = "3", v_agility = "2", v_perception = "3",
        v_ch1_show_yourself = "1",
      },
      date = 1725300000,
    },
    slots = nil,
  },
  slots = {
    [3] = {
      state = {
        v_current_scene = "Ch5-Departure",
        v_gold = "51",
        v_strength = "2", v_agility = "3",
        v_ch1_show_yourself = "1",
      },
      date = 1725290000,
      name = "Book 1 - Chapter 5",
    },
  },
}
