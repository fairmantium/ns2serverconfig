local kBotPersonalSettings = {
    { name = "Ashton M", isMale = true },
    { name = "Asraniel", isMale = true },
    { name = "BeigeAlert", isMale = true },
    { name = "Bonkers", isMale = true },
    { name = "Brackhar", isMale = true },
    { name = "Breadman", isMale = true },
    { name = "Chops", isMale = true },
    { name = "Comprox", isMale = true },
    { name = "CoolCookieCooks", isMale = true },
    { name = "Crispix", isMale = true },
    { name = "Darrin F.", isMale = true },
    { name = "Decoy", isMale = false },
    { name = "Explosif.be", isMale = true },
    { name = "Flaterectomy", isMale = true },
    { name = "Flayra", isMale = true },
    { name = "GISP", isMale = true },
    { name = "GeorgiCZ", isMale = true },
    { name = "Ghoul", isMale = true },
    { name = "Incredulous Dylan", isMale = true },
    { name = "Insane", isMale = true },
    { name = "Ironhorse", isMale = true },
    { name = "Joev", isMale = true },
    { name = "Kouji_San", isMale = true },
    { name = "KungFuDiscoMonkey", isMale = true },
    { name = "Lachdanan", isMale = true },
    { name = "Loki", isMale = true },
    { name = "MGS-3", isMale = true },
    { name = "Matso", isMale = true },
    { name = "Mazza", isMale = true },
    { name = "McGlaspie", isMale = true },
    { name = "Mendasp", isMale = true },
    { name = "Michael D.", isMale = true },
    { name = "MonsieurEvil", isMale = true },
    { name = "Narfwak", isMale = true },
    { name = "Numerik", isMale = true },
    { name = "Obraxis", isMale = true },
    { name = "Ooghi", isMale = true },
    { name = "OwNzOr", isMale = true },
    { name = "Patrick8675", isMale = true },
    { name = "Railo", isMale = true },
    { name = "Rantology", isMale = false },
    { name = "Relic25", isMale = true },
    { name = "Samusdroid", isMale = true },
    { name = "ScardyBob", isMale = true },
    { name = "Squeal Like a Pig", isMale = true },
    { name = "SteveRock", isMale = true },
    { name = "Steven G.", isMale = true },
    { name = "Strayan", isMale = true },
    { name = "Tex", isMale = true },
    { name = "TychoCelchuuu", isMale = true },
    { name = "Virsoul", isMale = true },
    { name = "WDI", isMale = true },
    { name = "WasabiOne", isMale = true },
    { name = "Zavaro", isMale = true },
    { name = "Zefram", isMale = true },
    { name = "Zinkey", isMale = true },
    { name = "devildog", isMale = true },
    { name = "m4x0r", isMale = true },
    { name = "moultano", isMale = true },
    { name = "puzl", isMale = true },
    { name = "remi.D", isMale = true },
    { name = "sewlek", isMale = true },
    { name = "tommyd", isMale = true },
    { name = "vartija", isMale = true },
    { name = "zaggynl", isMale = true },
}
local availableBotSettings = {}

local random = math.random
--Shuffles an array randomly
function table.shuffle(t)
    local n = #t
    for i = n, 1, -1 do
        local r = random(n)
        t[i], t[r] = t[r], t[i] --swap
    end

    return t
end

function PlayerBot.GetRandomBotSetting()
    if #availableBotSettings == 0 then
        for i = 1, #kBotPersonalSettings do
            availableBotSettings[i] = i
        end

        table.shuffle(availableBotSettings)
    end

    local random = table.remove(availableBotSettings)
    return kBotPersonalSettings[random]
end

function PlayerBot:UpdateNameAndGender()
    PROFILE("PlayerBot:UpdateNameAndGender")

    if self.botSetName then return end

    local player = self:GetPlayer()
    if not player then return end

    local name = player:GetName()
    local settings = self.GetRandomBotSetting()

    self.botSetName = true

    name = self:GetNamePrefix()..TrimName(settings.name)
    player:SetName(name)

    -- set gender
    self.client.variantData = {
        isMale = settings.isMale,
        marineVariant = kMarineVariant[kMarineVariant[math.random(1, #kMarineVariant)]],
        skulkVariant = kSkulkVariant[kSkulkVariant[math.random(1, #kSkulkVariant)]],
        gorgeVariant = kGorgeVariant[kGorgeVariant[math.random(1, #kGorgeVariant)]],
        lerkVariant = kLerkVariant[kLerkVariant[math.random(1, #kLerkVariant)]],
        fadeVariant = kFadeVariant[kFadeVariant[math.random(1, #kFadeVariant)]],
        onosVariant = kOnosVariant[kOnosVariant[math.random(1, #kOnosVariant)]],
        rifleVariant = kRifleVariant[kRifleVariant[math.random(1, #kRifleVariant)]],
        pistolVariant = kPistolVariant[kPistolVariant[math.random(1, #kPistolVariant)]],
        axeVariant = kAxeVariant[kAxeVariant[math.random(1, #kAxeVariant)]],
        shotgunVariant = kShotgunVariant[kShotgunVariant[math.random(1, #kShotgunVariant)]],
        exoVariant = kExoVariant[kExoVariant[math.random(1, #kExoVariant)]],
        shoulderPadIndex = 0
    }
    self.client:GetControllingPlayer():OnClientUpdated(self.client)

end