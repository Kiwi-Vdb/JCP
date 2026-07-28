local widget = widget

function widget:GetInfo()
	return {
		name = "JCP",
		desc = "JCP Micro and Macro unit sharing",
		author = "Vdb",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 9999,
		enabled = true,
		handler = true,
	}
end

local ROLE_MACRO = "macro"
local ROLE_MICRO = "micro"
local ROLE_NONE = "none"

local function makeSet(names)
	local result = {}
	for name in names:gmatch("%S+") do
		result[name] = true
	end
	return result
end

local macroShareWhitelist = makeSet([[
armflea armpw armrock armjeth armkam armham armwar armvader armaser armmark
armspy armfast armspid armamph armfido armfig armzeus armsptk armaak armmav
armsnipe armscab armfboy armmar armvang armraz armbanth corak corstorm corcrash
corthud corroach corspec corvoyr corspy corpyro coramph cormort cortermite corcan
corhrk coraak cordecom corsktl cormando corsumo corshiva corkarg corcat cordemon
corjugg corkorg armdecom armfav armmlv armflash armart armsam armpincer armstump
armjanus armjam armseer armgremlin armmart armlatnk armyork armcroc armmerl armbull
armmanni armthor corfav cormlv corgator cormist corwolv corgarp corlevlr corraid
corvrad coreter corsala cormart corsent correap corvroc corban corparrow cormabm
corgol cortrem armpeep armsfig armsehak armthund armsaber armsb armseap armhawk
armawac armpnix armbrawl armdfly armlance armstil armblade armliche corfink corbw
corveng corsfig corhunt corshad corsb corcut corseap corvamp corawac corhurc
corape cortitan corcrwh armpt armdecade armrecl armpship armsub armroy armsjam
armlship armsubk armaas armcrus armantiship armserp armmship armbats armepoch coresupp
corpt correcl corpship corsub corroy corsjam corfship corshark corarch corcrus
corantiship corssub cormship corbats corblackhy armsh armmh armah armanac armlun
corsh cormh corah corsnap corhal corsok
]])

local microShareWhitelist = makeSet([[
armck armrectr armack armcom armfark armdecom corck cornecro corcom corack
corfast cordecom armmlv armcv armbeaver armacv cormlv corcv cormuskrat coracv
armca armaca armatlas armhvytrans corvalk corhvytrans corseah armcs armrecl armmls
armacsub corcs correcl cormls coracsub armch corch
armfmkr armmakr armdrag armfdrag armeyes armwin armmex armrad armtide armfrad
armsolar armestor armuwes armamex armnanotc armnanotcplat armjamt armmstor armuwms
armadvsol armgeo armuwgeo armjuno armfort armveil armason armdf armmmkr armuwmmm
armarad armmoho armuwmme armsd armuwadvms armfatf armtarg armuwadves armgmm armamd
armageo armemp armuwageo armgate armfus armckfus armuwfus armafus
armsy armlab armvp armap armfhp armhp armamsub armplat armalab armavp armaap armasy
armshltx armshltxuw
armmine1 armmine2 armfmine3 armmine3 armrl armllt armfrt armtl armbeamer armdl
armclaw armferret armhlt armfhlt armcir armguard armpb armflak armfflak armatl
armkraken armmercury armamb armanni armbrtha armsilo armvulc
corfmkr cormakr cordrag corfdrag coreyes corwin cormex corrad cortide corjamt corfrad
corsolar corestor coruwes cornanotc cornanotcplat cormstor coruwms coradvsol corgeo
coruwgeo corjuno corfort corshroud corason cormmkr coruwmmm corarad cormoho coruwmme
corsd coruwadvms corfatf cortarg coruwadves corageo corfmd coruwageo corgate corfus
coruwfus corafus
corsy corlab corvp corap corfhp corhp coramsub corplat coralab coravp corasy coraap
corgantuw corgant
cormine1 cormine2 corfmine3 cormine3 corrl corfrt corllt cortl corhllt corexp cordl
cormaw cormadsam corfhlt corhlt corerad corpun corvipe corflak corenaa coratl cortron
corfdoom corscreamer cormexp cortoast cordoom corbhmth corint corsilo corbuzz
]])

local selectedRole
local pendingRole
local windowOpen = true
local myTeamID
local myAllyTeamID
local shareQueue = {}
local hitboxes = {}
local suppressedUnitIDs = {}
local chatWidget
local originalChatUnitTaken
local filteredChatUnitTaken
local originalChatUnitGiven
local filteredChatUnitGiven

local function drawBox(x1, y1, x2, y2, color)
	gl.Color(color[1], color[2], color[3], color[4])
	gl.Rect(x1, y1, x2, y2)
end

local function drawText(text, x, y, size, color, options)
	gl.Color(color[1], color[2], color[3], color[4])
	gl.Text(text, x, y, size, options or "o")
end

local function addHitbox(kind, value, x1, y1, x2, y2)
	hitboxes[#hitboxes + 1] = {
		kind = kind,
		value = value,
		x1 = x1,
		y1 = y1,
		x2 = x2,
		y2 = y2,
	}
end

local function contains(box, x, y)
	return x >= box.x1 and x <= box.x2 and y >= box.y1 and y <= box.y2
end

local function drawRoleWindow(vsx, vsy)
	local panelW = 380
	local panelH = 170
	local x2 = vsx - 12
	local y2 = vsy - 50
	local x1 = math.max(12, x2 - panelW)
	local y1 = math.max(12, y2 - panelH)
	local pad = 14
	local gap = 10
	local roleY2 = y2 - 58
	local roleY1 = roleY2 - 54
	local roleW = math.floor((panelW - (pad * 2) - (gap * 2)) / 3)
	local macroX1 = x1 + pad
	local macroX2 = macroX1 + roleW
	local microX1 = macroX2 + gap
	local microX2 = microX1 + roleW
	local noneX1 = microX2 + gap
	local noneX2 = x2 - pad
	local okX1 = x1 + pad
	local okX2 = x2 - pad
	local okY1 = y1 + 12
	local okY2 = okY1 + 30
	local green = { 0.16, 0.48, 0.22, 0.98 }
	local idle = { 0.12, 0.15, 0.18, 0.96 }

	drawBox(x1, y1, x2, y2, { 0.04, 0.045, 0.05, 0.96 })
	drawBox(x1, y2 - 38, x2, y2, { 0.12, 0.14, 0.16, 0.98 })
	drawText("JCP Role", x1 + pad, y2 - 25, 17, { 1, 1, 1, 1 })

	drawBox(macroX1, roleY1, macroX2, roleY2, pendingRole == ROLE_MACRO and green or idle)
	drawText("MACRO", (macroX1 + macroX2) / 2, roleY2 - 24, 16, { 1, 1, 1, 1 }, "oc")
	drawText("Combat units", (macroX1 + macroX2) / 2, roleY1 + 9, 11, { 0.86, 0.92, 1, 1 }, "oc")
	addHitbox("role", ROLE_MACRO, macroX1, roleY1, macroX2, roleY2)

	drawBox(microX1, roleY1, microX2, roleY2, pendingRole == ROLE_MICRO and green or idle)
	drawText("MICRO", (microX1 + microX2) / 2, roleY2 - 24, 16, { 1, 1, 1, 1 }, "oc")
	drawText("Builders/support", (microX1 + microX2) / 2, roleY1 + 9, 11, { 0.86, 0.92, 1, 1 }, "oc")
	addHitbox("role", ROLE_MICRO, microX1, roleY1, microX2, roleY2)

	drawBox(noneX1, roleY1, noneX2, roleY2, pendingRole == ROLE_NONE and green or idle)
	drawText("NONE", (noneX1 + noneX2) / 2, roleY2 - 24, 16, { 1, 1, 1, 1 }, "oc")
	drawText("Sharing off", (noneX1 + noneX2) / 2, roleY1 + 9, 11, { 0.86, 0.92, 1, 1 }, "oc")
	addHitbox("role", ROLE_NONE, noneX1, roleY1, noneX2, roleY2)

	drawBox(okX1, okY1, okX2, okY2, pendingRole and { 0.18, 0.36, 0.52, 0.98 } or { 0.11, 0.12, 0.13, 0.96 })
	drawText("OK", (okX1 + okX2) / 2, okY1 + 8, 14, pendingRole and { 1, 1, 1, 1 } or { 0.55, 0.55, 0.55, 1 }, "oc")
	addHitbox("ok", nil, okX1, okY1, okX2, okY2)
	addHitbox("panel", nil, x1, y1, x2, y2)
end

local function drawJCPButton(vsx, vsy)
	local x2 = vsx - 600
	local x1 = x2 - 64
	local y2 = vsy - 8
	local y1 = y2 - 30

	drawBox(x1, y1, x2, y2, { 0.14, 0.36, 0.20, 0.96 })
	drawText("JCP", (x1 + x2) / 2, y1 + 8, 14, { 1, 1, 1, 1 }, "oc")
	addHitbox("open", nil, x1, y1, x2, y2)
end

local function updateTeam()
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = myTeamID and Spring.GetTeamAllyTeamID(myTeamID) or nil
end

local function getTeammate()
	if not myAllyTeamID then
		return nil
	end

	local teams = Spring.GetTeamList(myAllyTeamID) or {}
	for i = 1, #teams do
		if teams[i] ~= myTeamID then
			return teams[i]
		end
	end

	return nil
end

local function currentWhitelist()
	if selectedRole == ROLE_MACRO then
		return macroShareWhitelist
	elseif selectedRole == ROLE_MICRO then
		return microShareWhitelist
	end
end

local function incomingWhitelist()
	if selectedRole == ROLE_MACRO then
		return microShareWhitelist
	elseif selectedRole == ROLE_MICRO then
		return macroShareWhitelist
	end
end

local function isExpectedIncomingUnit(unitDefID, oldTeamID, newTeamID)
	if newTeamID ~= myTeamID or oldTeamID ~= getTeammate() then
		return false
	end

	local whitelist = incomingWhitelist()
	local unitDef = UnitDefs[unitDefID]
	return whitelist and unitDef and whitelist[unitDef.name] == true
end

local function restoreChatFilter()
	if chatWidget and originalChatUnitTaken and chatWidget.UnitTaken == filteredChatUnitTaken then
		chatWidget.UnitTaken = originalChatUnitTaken
	end

	if chatWidget and originalChatUnitGiven and chatWidget.UnitGiven == filteredChatUnitGiven then
		chatWidget.UnitGiven = originalChatUnitGiven
	end

	chatWidget = nil
	originalChatUnitTaken = nil
	filteredChatUnitTaken = nil
	originalChatUnitGiven = nil
	filteredChatUnitGiven = nil
end

local function installChatFilter()
	-- BAR normally gives user widgets a restricted widgetHandler. JCP requests
	-- full handler access above, but keep this guard so a future BAR change
	-- cannot stop the unit-sharing part of the widget from loading.
	if not widgetHandler or type(widgetHandler.FindWidget) ~= "function" then
		return
	end

	local currentChatWidget = widgetHandler:FindWidget("Chat")
	if currentChatWidget == chatWidget
		and (not filteredChatUnitTaken or currentChatWidget.UnitTaken == filteredChatUnitTaken)
		and (not filteredChatUnitGiven or currentChatWidget.UnitGiven == filteredChatUnitGiven)
	then
		return
	end

	restoreChatFilter()
	if not currentChatWidget
		or (type(currentChatWidget.UnitTaken) ~= "function" and type(currentChatWidget.UnitGiven) ~= "function")
	then
		return
	end

	chatWidget = currentChatWidget
	if type(chatWidget.UnitTaken) == "function" then
		originalChatUnitTaken = chatWidget.UnitTaken
		local originalTaken = originalChatUnitTaken

		filteredChatUnitTaken = function(self, unitID, unitDefID, oldTeamID, newTeamID)
			local expires = suppressedUnitIDs[unitID]
			if expires then
				suppressedUnitIDs[unitID] = nil
				if Spring.GetGameFrame() <= expires then
					return
				end
			end

			return originalTaken(self, unitID, unitDefID, oldTeamID, newTeamID)
		end

		chatWidget.UnitTaken = filteredChatUnitTaken
	end

	if type(chatWidget.UnitGiven) == "function" then
		originalChatUnitGiven = chatWidget.UnitGiven
		local originalGiven = originalChatUnitGiven

		filteredChatUnitGiven = function(self, unitID, unitDefID, newTeamID, oldTeamID)
			if isExpectedIncomingUnit(unitDefID, oldTeamID, newTeamID) then
				return
			end

			return originalGiven(self, unitID, unitDefID, newTeamID, oldTeamID)
		end

		chatWidget.UnitGiven = filteredChatUnitGiven
	end
end

local function processShareQueue()
	if #shareQueue == 0 then
		return
	end

	installChatFilter()
	local queued = shareQueue
	shareQueue = {}
	local teammate = getTeammate()
	if not teammate then
		return
	end

	local units = {}
	for i = 1, #queued do
		local entry = queued[i]
		if Spring.GetUnitTeam(entry.unitID) == myTeamID and Spring.GetUnitDefID(entry.unitID) == entry.unitDefID then
			units[#units + 1] = entry.unitID
		end
	end

	if #units == 0 then
		return
	end

	local expires = Spring.GetGameFrame() + 90
	for i = 1, #units do
		suppressedUnitIDs[units[i]] = expires
	end

	local previousSelection = Spring.GetSelectedUnits()
	Spring.SelectUnitArray(units)
	Spring.ShareResources(teammate, "units")
	Spring.SelectUnitArray(previousSelection)
end

function widget:Initialize()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end

	updateTeam()
	installChatFilter()
end

function widget:PlayerChanged()
	if Spring.GetSpectatingState() then
		widgetHandler:RemoveWidget(self)
		return
	end

	updateTeam()
end

function widget:Shutdown()
	restoreChatFilter()
end

function widget:DrawScreen()
	hitboxes = {}
	local vsx, vsy = Spring.GetViewGeometry()

	if windowOpen then
		drawRoleWindow(vsx, vsy)
	else
		drawJCPButton(vsx, vsy)
	end

	gl.Color(1, 1, 1, 1)
end

function widget:IsAbove(x, y)
	for i = 1, #hitboxes do
		if contains(hitboxes[i], x, y) then
			return true
		end
	end
	return false
end

function widget:MousePress(x, y, button)
	if button ~= 1 then
		return false
	end

	for i = 1, #hitboxes do
		local box = hitboxes[i]
		if contains(box, x, y) then
			if box.kind == "role" then
				pendingRole = box.value
			elseif box.kind == "ok" and pendingRole then
				selectedRole = pendingRole
				if selectedRole == ROLE_NONE then
					shareQueue = {}
				end
				windowOpen = false
			elseif box.kind == "open" then
				pendingRole = selectedRole
				windowOpen = true
			end
			return true
		end
	end

	return false
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
	if unitTeam ~= myTeamID then
		return
	end

	local whitelist = currentWhitelist()
	local unitDef = UnitDefs[unitDefID]
	if whitelist and unitDef and whitelist[unitDef.name] then
		shareQueue[#shareQueue + 1] = {
			unitID = unitID,
			unitDefID = unitDefID,
		}
	end
end

function widget:GameFrame(frame)
	if frame % 30 == 0 then
		installChatFilter()
		for unitID, expires in pairs(suppressedUnitIDs) do
			if frame > expires then
				suppressedUnitIDs[unitID] = nil
			end
		end
	end

	processShareQueue()
end
