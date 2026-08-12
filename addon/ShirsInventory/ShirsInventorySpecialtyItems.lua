-- Herb and enchanting-material IDs accepted by Vanilla 1.12 specialty bags.
-- Sources are pinned in tests/fixtures/specialty_bag_family_items.json.

local herbBagItemIDs = {
  [765] = true, -- Silverleaf
  [785] = true, -- Mageroyal
  [2447] = true, -- Peacebloom
  [2449] = true, -- Earthroot
  [2450] = true, -- Briarthorn
  [2452] = true, -- Swiftthistle
  [2453] = true, -- Bruiseweed
  [3355] = true, -- Wild Steelbloom
  [3356] = true, -- Kingsblood
  [3357] = true, -- Liferoot
  [3358] = true, -- Khadgar's Whisker
  [3369] = true, -- Grave Moss
  [3818] = true, -- Fadeleaf
  [3819] = true, -- Wintersbite
  [3820] = true, -- Stranglekelp
  [3821] = true, -- Goldthorn
  [4625] = true, -- Firebloom
  [5173] = true, -- Deathweed
  [8153] = true, -- Wildvine
  [8831] = true, -- Purple Lotus
  [8836] = true, -- Arthas' Tears
  [8838] = true, -- Sungrass
  [8839] = true, -- Blindweed
  [8845] = true, -- Ghost Mushroom
  [8846] = true, -- Gromsblood
  [11040] = true, -- Morrowgrain
  [13463] = true, -- Dreamfoil
  [13464] = true, -- Golden Sansam
  [13465] = true, -- Mountain Silversage
  [13466] = true, -- Plaguebloom
  [13467] = true, -- Icecap
  [13468] = true, -- Black Lotus
  [19726] = true, -- Bloodvine
}

local enchantingBagItemIDs = {
  [10938] = true, -- Lesser Magic Essence
  [10939] = true, -- Greater Magic Essence
  [10940] = true, -- Strange Dust
  [10978] = true, -- Small Glimmering Shard
  [10998] = true, -- Lesser Astral Essence
  [11082] = true, -- Greater Astral Essence
  [11083] = true, -- Soul Dust
  [11084] = true, -- Large Glimmering Shard
  [11134] = true, -- Lesser Mystic Essence
  [11135] = true, -- Greater Mystic Essence
  [11137] = true, -- Vision Dust
  [11138] = true, -- Small Glowing Shard
  [11139] = true, -- Large Glowing Shard
  [11174] = true, -- Lesser Nether Essence
  [11175] = true, -- Greater Nether Essence
  [11176] = true, -- Dream Dust
  [11177] = true, -- Small Radiant Shard
  [11178] = true, -- Large Radiant Shard
  [14343] = true, -- Small Brilliant Shard
  [14344] = true, -- Large Brilliant Shard
  [16202] = true, -- Lesser Eternal Essence
  [16203] = true, -- Greater Eternal Essence
  [16204] = true, -- Illusion Dust
  [20725] = true, -- Nexus Crystal
}

function ShirsInventory_GetStaticSpecialtyItemClass(itemID)
  if herbBagItemIDs[itemID] then return "herb" end
  if enchantingBagItemIDs[itemID] then return "enchanting" end
  return nil
end
