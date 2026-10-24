InventoryCompanion = InventoryCompanion or {}
local this = InventoryCompanion

local finalCurrencyList = {
    {
        DisplayName = "Alliance Points",
        LookupConstant = CURT_ALLIANCE_POINTS,
        Enum = "ALLIANCE_POINTS",
        TextureList = {
            "/esoui/art/currency/alliancepoints_32.dds",
            "/esoui/art/currency/alliancepoints_64.dds",
            "/esoui/art/currency/alliancepoints_mipmap.dds",
            "/esoui/art/currency/alliancepoints.dds",
            "/esoui/art/currency/gamepad/gp_alliancepoints_64.dds",
            "/esoui/art/currency/gamepad/gp_alliancepoints_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_alliancepoints.dds",
        },
    },
    {
        DisplayName = "Crown Gems",
        LookupConstant = CURT_CROWN_GEMS,
        Enum = "CROWN_GEMS",
        TextureList = {
            "/esoui/art/currency/crowngem_mipmap.dds",
            "/esoui/art/currency/currency_crown_gems.dds",
            "/esoui/art/currency/gamepad/gp_crown_gems.dds",
            "/esoui/art/currency/gamepad/gp_crowngems_mipmap.dds",
        },
    },
    {
        DisplayName = "Crowns",
        LookupConstant = CURT_CROWNS,
        Enum = "CROWNS",
        TextureList = {
            "/esoui/art/currency/crowns_mipmap.dds",
            "/esoui/art/currency/currency_crown.dds",
            "/esoui/art/currency/currency_crowns_32.dds",
            "/esoui/art/currency/gamepad/gp_crowns_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_crowns.dds",
        },
    },
    {
        DisplayName = "Gold",
        LookupConstant = CURT_MONEY,
        Enum = "GOLD",
        TextureList = {
            "/esoui/art/currency/currency_gold_32.dds",
            "/esoui/art/currency/currency_gold_64.dds",
            "/esoui/art/currency/currency_gold.dds",
            "/esoui/art/currency/gamepad/gp_gold_64.dds",
            "/esoui/art/currency/gamepad/gp_gold_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_gold.dds",
            "/esoui/art/currency/gold_mipmap.dds",
        },
    },
    {
        DisplayName = "Imperial Fragments",
        LookupConstant = CURT_IMPERIAL_FRAGMENTS,
        Enum = "IMPERIAL_FRAGMENTS",
        TextureList = {
            "/esoui/art/currency/currency_imperial_trophy_key_16.dds",
            "/esoui/art/currency/currency_imperial_trophy_key_32.dds",
            "/esoui/art/currency/currency_imperial_trophy_key_64.dds",
            "/esoui/art/currency/currency_imperial_trophy_key_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_currency_imperial_trophy_key_mipmaps.dds",
            "/esoui/art/currency/gamepad/gp_currency_imperial_trophy_key.dds",
        },
    },
    {
        DisplayName = "Seals of Endeavor",
        LookupConstant = CURT_SEALS,
        Enum = "SEALS_OF_ENDEAVOR",
        TextureList = {
            "/esoui/art/currency/currency_seals_of_endeavor_32.dds",
            "/esoui/art/currency/currency_seals_of_endeavor_64.dds",
            "/esoui/art/currency/currency_seals_of_endeavor_mipmaps.dds",
            "/esoui/art/currency/gamepad/gp_currency_seals_of_endeavor_64.dds",
            "/esoui/art/currency/gamepad/gp_currency_seals_of_endeavor_mipmaps.dds",
        },
    },
    {
        DisplayName = "Tel Var Stones",
        LookupConstant = CURT_TELVAR_STONES,
        Enum = "TELVAR_STONES",
        TextureList = {
            "/esoui/art/currency/currency_telvar_32.dds",
            "/esoui/art/currency/currency_telvar_64.dds",
            "/esoui/art/currency/currency_telvar.dds",
            "/esoui/art/currency/gamepad/gp_telvar_64.dds",
            "/esoui/art/currency/gamepad/gp_telvar_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_telvar.dds",
            "/esoui/art/currency/telvar_mipmap.dds",
        },
    },
    {
        DisplayName = "Tome Points",
        LookupConstant = CURT_TOME_POINTS,
        Enum = "TOME_POINTS",
        TextureList = {
            "/esoui/art/currency/currency_tomes_base.dds",
            "/esoui/art/currency/currency_tomes_premium.dds",
            "/esoui/art/currency/gamepad/gp_currency_tomepoints.dds",
            "/esoui/art/currency/u49_tt_cacheoftomepoints_16.dds",
            "/esoui/art/currency/u49_tt_cacheoftomepoints_32.dds",
            "/esoui/art/currency/u49_tt_cacheoftomepoints_64.dds",
            "/esoui/art/currency/u49_tt_cacheoftomepoints_mipmaps.dds",
            "/esoui/art/currency/u49_tt_cacheoftomepoints.dds",
            "/esoui/art/currency/u49_tt_premiumtomepoints_16.dds",
            "/esoui/art/currency/u49_tt_premiumtomepoints_32.dds",
            "/esoui/art/currency/u49_tt_premiumtomepoints_64.dds",
            "/esoui/art/currency/u49_tt_premiumtomepoints_mipmap.dds",
            "/esoui/art/currency/u49_tt_premiumtomepoints.dds",
            "/esoui/art/currency/u49_tt_tomepoints_16.dds",
            "/esoui/art/currency/u49_tt_tomepoints_32.dds",
            "/esoui/art/currency/u49_tt_tomepoints_64.dds",
            "/esoui/art/currency/u49_tt_tomepoints_mipmap.dds",
            "/esoui/art/currency/u49_tt_tomepoints.dds",
        },
    },
    {
        DisplayName = "Trade Bars",
        LookupConstant = CURT_TRADE_BARS,
        Enum = "TRADE_BARS",
        TextureList = {
            "/esoui/art/currency/gamepad/gp_currency_tradebars.dds",
            "/esoui/art/currency/u49_tt_tradebars_16.dds",
            "/esoui/art/currency/u49_tt_tradebars_32.dds",
            "/esoui/art/currency/u49_tt_tradebars_64.dds",
            "/esoui/art/currency/u49_tt_tradebars_mipmap.dds",
            "/esoui/art/currency/u49_tt_tradebars.dds",
        },
    },    
	{
        DisplayName = "Transmute Crystals",
        LookupConstant = CURT_TRANSMUTE_CRYSTALS,
        Enum = "TRANSMUTE_CRYSTALS",
        TextureList = {
            "/esoui/art/currency/currency_seedcrystal_16.dds",
            "/esoui/art/currency/currency_seedcrystal_32.dds",
            "/esoui/art/currency/currency_seedcrystal_64.dds",
            "/esoui/art/currency/currency_seedcrystal_mipmap.dds",
            "/esoui/art/currency/currency_seedcrystals_multi_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_seedcrystal_mipmap.dds",
            "/esoui/art/currency/icon_seedcrystal.dds",
        },
    },
    {
        DisplayName = "Undaunted Crests",
        LookupConstant = CURT_UNDAUNTED_CRESTS,
        Enum = "UNDAUNTED_CRESTS",
        TextureList = {
            "/esoui/art/currency/currency_u51_solodungeon_16.dds",
            "/esoui/art/currency/currency_u51_solodungeon_32.dds",
            "/esoui/art/currency/currency_u51_solodungeon_64.dds",
            "/esoui/art/currency/currency_u51_solodungeon_mipmaps.dds",
            "/esoui/art/currency/currency_u51_solodungeon_multi_16.dds",
            "/esoui/art/currency/currency_u51_solodungeon_multi_32.dds",
            "/esoui/art/currency/currency_u51_solodungeon_multi_64.dds",
            "/esoui/art/currency/currency_u51_solodungeon_multi_mipmaps.dds",
            "/esoui/art/currency/gamepad/gp_currency_u51_solodungeon_64.dds",
            "/esoui/art/currency/gamepad/gp_currency_u51_solodungeon_mipmaps.dds",
            "/esoui/art/currency/gamepad/gp_currency_u51_solodungeon.dds",
            "/esoui/art/currency/u51_infinity_loop.dds",
        },
    },
    {
        DisplayName = "Undaunted Keys",
        LookupConstant = CURT_UNDAUNTED_KEYS,
        Enum = "UNDAUNTED_KEYS",
        TextureList = {
            "/esoui/art/currency/gamepad/gp_undauntedkey_16.dds",
            "/esoui/art/currency/gamepad/gp_undauntedkey_64.dds",
            "/esoui/art/currency/gamepad/gp_undauntedkey_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_undauntedkey.dds",
            "/esoui/art/currency/undauntedkey_16.dds",
            "/esoui/art/currency/undauntedkey_64.dds",
            "/esoui/art/currency/undauntedkey_mipmap.dds",
            "/esoui/art/currency/undauntedkey_multi_16.dds",
            "/esoui/art/currency/undauntedkey_multi_64.dds",
            "/esoui/art/currency/undauntedkey_multi_mipmap.dds",
            "/esoui/art/currency/undauntedkey_multi.dds",
            "/esoui/art/currency/undauntedkey.dds",
        },
    },
    {
        DisplayName = "Writ Vouchers",
        LookupConstant = CURT_WRIT_VOUCHERS,
        Enum = "WRIT_VOUCHERS",
        TextureList = {
            "/esoui/art/currency/currency_writvoucher_64.dds",
            "/esoui/art/currency/currency_writvoucher.dds",
            "/esoui/art/currency/gamepad/gp_writvoucher_64.dds",
            "/esoui/art/currency/gamepad/gp_writvoucher_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_writvoucher.dds",
            "/esoui/art/currency/writvoucher_mipmap.dds",
        },
    },
}

local currencyTextures = {
    ["archivalfragments"] = {
        DisplayName = "Archival Fragments",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/archivalfragments_16.dds",
            "/esoui/art/currency/archivalfragments_32.dds",
            "/esoui/art/currency/archivalfragments_64.dds",
            "/esoui/art/currency/archivalfragments_mipmaps.dds",
            "/esoui/art/currency/gamepad/gp_archivalfragments_32.dds",
            "/esoui/art/currency/gamepad/gp_archivalfragments_64.dds",
            "/esoui/art/currency/gamepad/gp_archivalfragments_mipmaps.dds",
        },
    },
    ["battletoken"] = {
        DisplayName = "Battle Token",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/battletoken.dds",
        },
    },
    ["eventticket"] = {
        DisplayName = "Event Tickets",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/currency_eventticket_mipmap.dds",
            "/esoui/art/currency/currency_eventticket.dds",
            "/esoui/art/currency/gamepad/gp_eventticket_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_eventticket.dds",
            "/esoui/art/currency/gamepad/gp_eventticket1_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_eventticket1.dds",
            "/esoui/art/currency/icon_eventticket_loot_mipmap.dds",
            "/esoui/art/currency/icon_eventticket_loot_shadow_mipmap.dds",
            "/esoui/art/currency/icon_eventticket_loot_shadow.dds",
            "/esoui/art/currency/icon_eventticket_loot.dds",
        },
    },
    ["fightersguild"] = {
        DisplayName = "Fighters Guild",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/currency_fightersguild.dds",
        },
    },
    ["inspiration"] = {
        DisplayName = "Inspiration",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/currency_inspiration_32.dds",
            "/esoui/art/currency/currency_inspiration_64.dds",
            "/esoui/art/currency/currency_inspiration.dds",
            "/esoui/art/currency/gamepad/gp_inspiration_64.dds",
            "/esoui/art/currency/gamepad/gp_inspiration_mipmap.dds",
            "/esoui/art/currency/gamepad/gp_inspiration.dds",
            "/esoui/art/currency/inspiration_mipmap.dds",
        },
    },
    ["magesguild"] = {
        DisplayName = "Mages Guild",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/currency_magesguild.dds",
        },
    },    
    ["thievesguild"] = {
        DisplayName = "Thieves Guild",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/currency_thievesguild.dds",
        },
    },    
    ["premiumpoints"] = {
        DisplayName = "Premium Points",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/gamepad/gp_currency_premiumpoints.dds",
        },
    },
    ["reroll"] = {
        DisplayName = "Reroll Currency",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/gamepad/gp_currency_reroll.dds",
            "/esoui/art/currency/u49_tt_reroll_16.dds",
            "/esoui/art/currency/u49_tt_reroll_32.dds",
            "/esoui/art/currency/u49_tt_reroll_64.dds",
            "/esoui/art/currency/u49_tt_reroll_mipmaps.dds",
            "/esoui/art/currency/u49_tt_reroll.dds",
        },
    },
    ["ttcache"] = {
        DisplayName = "Tome Cache",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/gamepad/gp_currency_ttcache.dds",
        },
    },
    ["token_clothing"] = {
        DisplayName = "Clothing Token",
        AccountEnum = -1,
        CharacterEnum = -1,
        TextureList = {
            "/esoui/art/currency/gamepad/gp_token_clothing_32.dds",
            "/esoui/art/currency/gamepad/gp_token_clothing_64.dds",
            "/esoui/art/currency/gamepad/gp_token_clothing_mipmap.dds",
            "/esoui/art/currency/token_clothing_16.dds",
            "/esoui/art/currency/token_clothing_32.dds",
            "/esoui/art/currency/token_clothing_64.dds",
            "/esoui/art/currency/token_clothing_mipmap.dds",
        },
    },
} 


-- Currency Enum Definition
this.CurrencyType = {
    ALLIANCE_POINTS        = 1,
    CROWN_GEMS             = 2,
    CROWNS                 = 3,
    GOLD                   = 4,
    IMPERIAL_FRAGMENTS     = 5,
    SEALS_OF_ENDEAVOR      = 6,
    TELVAR_STONES          = 7,
    TOME_POINTS            = 8,
    TRADE_BARS             = 9,
    TRANSMUTE_CRYSTALS     = 10,
    UNDAUNTED_CRESTS       = 11,
    UNDAUNTED_KEYS         = 12,
    WRIT_VOUCHERS          = 13,
    CACHES_OF_TOME_POINTS  = 14,
    OUTFIT_CHANGE_TOKENS   = 15,
    PREMIUM_TOME_TOKENS    = 16,
    ARCHIVAL_FRAGMENTS     = 17,
    EVENT_TICKETS          = 18,
    FIGHTERS_GUILD         = 19,
    MAGES_GUILD            = 20,
    SEED_CRYSTALS          = 21,
    THIEVES_GUILD          = 22,
    SOLO_DUNGEON           = 23,
    REROLL                 = 24,
}

local knownFakeConstants = {
	{ name = "CURT_ARCHIVAL_FRAGMENTS", value = CURT_ARCHIVAL_FRAGMENTS },
    { name = "CURT_EVENT_TICKETS",      value = CURT_EVENT_TICKETS },
    { name = "CURT_INSPIRATION",        value = CURT_INSPIRATION },
    { name = "CURT_FIGHTERS_GUILD",     value = CURT_FIGHTERS_GUILD },
    { name = "CURT_MAGES_GUILD",        value = CURT_MAGES_GUILD },
    { name = "CURT_THIEVES_GUILD",      value = CURT_THIEVES_GUILD },
    { name = "CURT_SEED_CRYSTALS",      value = CURT_SEED_CRYSTALS },
    { name = "CURT_PREMIUM_POINTS",     value = CURT_PREMIUM_POINTS },
    { name = "CURT_REROLL",             value = CURT_REROLL },
    { name = "CURT_TOME_CACHE",         value = CURT_TOME_CACHE },
    { name = "CURT_CLOTHING_TOKEN",     value = CURT_CLOTHING_TOKEN },
    { name = "CURT_BATTLE_TOKEN",       value = CURT_BATTLE_TOKEN },
    { name = "CURT_SOLO_DUNGEON",       value = CURT_SOLO_DUNGEON },
}

local currencyEnums = {
    { name = "CURT_ALLIANCE_POINTS",      value = CURT_ALLIANCE_POINTS },
    { name = "CURT_CROWN_GEMS",           value = CURT_CROWN_GEMS },
    { name = "CURT_CROWNS",               value = CURT_CROWNS },
    { name = "CURT_IMPERIAL_FRAGMENTS",   value = CURT_IMPERIAL_FRAGMENTS },
    { name = "CURT_SEALS",                value = CURT_SEALS },
    { name = "CURT_TELVAR_STONES",        value = CURT_TELVAR_STONES },
    { name = "CURT_TOME_POINTS",          value = CURT_TOME_POINTS },
    { name = "CURT_TRADE_BARS",           value = CURT_TRADE_BARS },
    { name = "CURT_TRANSMUTE_CRYSTALS",   value = CURT_TRANSMUTE_CRYSTALS },
    { name = "CURT_UNDAUNTED_CRESTS",     value = CURT_UNDAUNTED_CRESTS },
    { name = "CURT_UNDAUNTED_KEYS",       value = CURT_UNDAUNTED_KEYS },
    { name = "CURT_WRIT_VOUCHERS",        value = CURT_WRIT_VOUCHERS },
    { name = "CURT_MONEY",                value = CURT_MONEY },
    { name = "CURT_FAKE",                 value = CURT_FAKE },
}

local currencyEnums = {    
    { name = "CURT_ALLIANCE_POINTS", value = CURT_ALLIANCE_POINTS },
    { name = "CURT_ARCHIVAL_FORTUNES", value = CURT_ARCHIVAL_FORTUNES },
    { name = "CURT_CHAOTIC_CREATIA", value = CURT_CHAOTIC_CREATIA },
    { name = "CURT_CROWN_GEMS", value = CURT_CROWN_GEMS },
    { name = "CURT_CROWNS", value = CURT_CROWNS },
    { name = "CURT_ENDEAVOR_SEALS", value = CURT_ENDEAVOR_SEALS },
    { name = "CURT_ENDLESS_DUNGEON", value = CURT_ENDLESS_DUNGEON },
    { name = "CURT_IMPERIAL_FRAGMENTS", value = CURT_IMPERIAL_FRAGMENTS },
    { name = "CURT_ITERATION_BEGIN", value = CURT_ITERATION_BEGIN },
    { name = "CURT_ITERATION_END", value = CURT_ITERATION_END },
    { name = "CURT_MONEY", value = CURT_MONEY },
    { name = "CURT_NONE", value = CURT_NONE },
    { name = "CURT_SEALS", value = CURT_SEALS },
    { name = "CURT_STYLE_STONES", value = CURT_STYLE_STONES },
    { name = "CURT_TELVAR_STONES", value = CURT_TELVAR_STONES },
    { name = "CURT_TOME_CHALLENGE_REROLLS", value = CURT_TOME_CHALLENGE_REROLLS },
    { name = "CURT_TOME_POINT_CACHES", value = CURT_TOME_POINT_CACHES },
    { name = "CURT_TOME_POINTS", value = CURT_TOME_POINTS },
    { name = "CURT_TOME_TOKENS", value = CURT_TOME_TOKENS },
    { name = "CURT_TRADE_BARS", value = CURT_TRADE_BARS },
    { name = "CURT_TRANSMUTE_CRYSTALS", value = CURT_TRANSMUTE_CRYSTALS },
    { name = "CURT_UNDAUNTED_CRESTS", value = CURT_UNDAUNTED_CRESTS },
    { name = "CURT_UNDAUNTED_KEYS", value = CURT_UNDAUNTED_KEYS },
    { name = "CURT_WRIT_VOUCHERS", value = CURT_WRIT_VOUCHERS },
}

function this.DebugCurrencyGuesses()
    for _, info in ipairs(currencyEnums) do
        if not info.value then 
            d(info.name .. " is INVALID (nil global constant)")
        else
            local charAmt = GetCurrencyAmount(info.value, CURRENCY_LOCATION_CHARACTER)
            local bankAmt = GetCurrencyAmount(info.value, CURRENCY_LOCATION_BANK)
            local accAmt  = GetCurrencyAmount(info.value, CURRENCY_LOCATION_ACCOUNT)
            
            if not charAmt and not bankAmt and not accAmt then
                d(string.format("[DEAD] %s (%d) returned nil across all locations.", info.name, info.value))
            else
                d(string.format("[VALID] %s (%d) -> Char: %s | Bank: %s | Acc: %s", 
                    info.name, info.value, tostring(charAmt), tostring(bankAmt), tostring(accAmt)))
            end
        end
    end
end

function this.DebugCurrency()
	for _, info in ipairs(currencyEnums) do
		if not info.value then 
			d(info.name .. " is INVALID")
		else
			d(info.name .. " is " .. tostring(info.value))
			local charAmt = GetCurrencyAmount(info.value, CURRENCY_LOCATION_CHARACTER)
			local bankAmt = GetCurrencyAmount(info.value, CURRENCY_LOCATION_BANK)
			local accAmt  = GetCurrencyAmount(info.value, CURRENCY_LOCATION_ACCOUNT)
			local totalAmt = charAmt + bankAmt + accAmt
						
			d(string.format("%s (%d): %d",info.name, info.value, totalAmt))
		end
	end
end

 