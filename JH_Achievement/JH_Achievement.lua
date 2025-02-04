-- @Author: Webster
-- @Date:   2016-02-26 23:33:04
-- @Last Modified by:   Webster
-- @Last Modified time: 2016-04-28 14:19:49
local _L = JH.LoadLangPack
local Achievement = {}
local ACHI_ANCHOR  = { s = "CENTER", r = "CENTER", x = 0, y = 0 }
local ACHI_ROOT_URL = "http://game.j3ui.com/wiki/"
-- local ACHI_ROOT_URL = "http://10.37.210.22:8088/wiki/"
-- local ACHI_ROOT_URL = "http://10.0.20.20:8090/wiki/"
local ACHI_CLIENT_LANG = select(3, GetVersion())

-- 获取玩家成就完成信息 2byte存8个 无法获取带进度的
local sformat = string.format
local tinsert = table.insert

local function Bitmap2Number(t)
	local n = 0
	for i, v in ipairs(t) do
		if v and v ~= 0 then
			n = n + 2 ^ (i - 1)
		end
	end
	return sformat("%02x", n)
end

local function GetAchievementList()
	local me    = GetClientPlayer()
	local data  = {}
	local max   = g_tTable.Achievement:GetRow(g_tTable.Achievement:GetRowCount()).dwID
	local nPoint = 0
	for i = 1, max do
		local bCheck = me.IsAchievementAcquired(i) or false
		data[i] = bCheck
		if bCheck then
			local row = g_tTable.AchievementInfo:Search(i)
			if row and row.nPoint then
				nPoint = nPoint + row.nPoint
			end
		end
	end
	local bitmap = {}
	local i = 1
	while i < max do
		local tt = {}
		for a = i, i + 7 do
			tinsert(tt, data[a])
		end
		tinsert(bitmap, Bitmap2Number(tt))
		i = i + 8
	end
	return bitmap, data, nPoint
end

JH_Achievement = {}

function JH_Achievement.OnFrameCreate()
	this:RegisterEvent("UI_SCALED")
	JH.RegisterGlobalEsc("Achievement", Achievement.IsOpened, Achievement.ClosePanel)
	local handle = this:Lookup("", "")
	this.pedia   = this:Lookup("WndScroll_Pedia", "")
	this.link    = handle:Lookup("Text_Link")
	this.title   = handle:Lookup("Text_Title")
	this.desc    = handle:Lookup("Text_Desc")
	this.box     = handle:Lookup("Box_Icon")
	this:Lookup("Btn_Edit"):Lookup("", "Text_Edit"):SetText(_L["perfection"])
	Achievement.UpdateAnchor(this)
end

function JH_Achievement.OnItemMouseEnter()
	local szName = this:GetName()
	if szName == "Box_Icon" then
		this:SetObjectMouseOver(true)
		local frame = this:GetRoot()
		local x, y  = this:GetAbsPos()
		local w, h  = this:GetSize()
		local xml   = {}
		table.insert(xml, GetFormatText(frame.title:GetText() .. "\n", 27))
		table.insert(xml, GetFormatText(frame.desc:GetText(), 41))
		OutputTip(table.concat(xml), 300, { x, y, w, h })
	elseif szName == "Text_Link" then
		this:SetFontScheme(35)
	elseif szName == "Image_Wechat" then
		local x, y = this:GetAbsPos()
		local w, h = this:GetSize()
		OutputTip(GetFormatImage(JH.GetAddonInfo().szRootPath .. "JH_Achievement/ui/qrcode_for_j3wikis.tga", nil, 200, 200), 200, { x, y, w, h })
	end
end

function JH_Achievement.OnItemMouseLeave()
	local szName = this:GetName()
	if szName == "Box_Icon" then
		this:SetObjectMouseOver(false)
		HideTip()
	elseif szName == "Text_Link" then
		this:SetFontScheme(172)
	elseif szName == "Image_Wechat" then
		HideTip()
	end
end

function JH_Achievement.OnFrameDragEnd()
	ACHI_ANCHOR = GetFrameAnchor(this)
end

function JH_Achievement.OnEvent(szEvent)
	if szEvent == "UI_SCALED" then
		Achievement.UpdateAnchor(this)
	end
end

function JH_Achievement.OnEditChanged()
	local szName = this:GetName()
	if szName == "Edit_EditMode" then
		this:GetRoot().szText = this:GetText()
		this:GetRoot():Lookup("Btn_Send"):Enable(true)
	end
end

function JH_Achievement.OnLButtonClick()
	local szName = this:GetName()
	if szName == "Btn_Close" then
		Achievement.ClosePanel()
	elseif szName == "Btn_Edit" then
		if ACHI_CLIENT_LANG ~= "zhcn" and ACHI_CLIENT_LANG ~= "zhtw" then
			return JH.Alert(_L["Sorry, Does not support this function"])
		end
		if this:GetRoot().szText == "" or this:GetRoot().szText == _L["Achi Default Templates"] then
			Achievement.EditMode(true)
		else
			JH.Confirm(_L["ACHI_TIPS"], function()
				Achievement.EditMode(true)
			end)
		end
	elseif szName == "Btn_Cancel" then
		Achievement.EditMode(false)
	elseif szName == "Btn_Send" then
		JH.Confirm(_L["Confirm?"], Achievement.Send)
	end
end

function JH_Achievement.OnItemLButtonClick()
	local szName = this:GetName()
	if szName == "Text_Link" then
		local frame = this:GetRoot()
		OpenInternetExplorer(ACHI_ROOT_URL .. "detail/" .. frame.dwAchievement)
		if not frame.bEdit then
			Achievement.ClosePanel()
		end
	end
end
-- OnItemUpdateSize autosize callback
function JH_Achievement.OnItemUpdateSize()
	local item = this
	if item and item:IsValid() and item.src then
		local w, h = item:GetSize()
		local fScale = Station.GetUIScale()
		local fW, fH = w / fScale, h / fScale
		if fW > 670 then -- fixed size
			local f = 670 / fW
			item:SetSize(fW * f, fH * f)
		else
			item:SetSize(fW, fH)
		end
		item:RegisterEvent(16)
		item.OnItemLButtonClick = function()
			local sW, sH = fW + 20, fH + 40
			local ui = GUI.CreateFrame("JH_ImageView", { w = sW, h = sH, nStyle = 2, title = "Image View" }):BackGround(222, 210, 190)
			local hImageview = ui:Raw():GetRoot()
			hImageview.fScale = 1
			local img = ui:Append("Image", { x = 10, y = 0, w = fW, h = fH, file = item.localsrc }):Click(function()
				if hImageview.lock then
					hImageview.lock = nil
				else
					JH.Animate(hImageview, 200):Pos({0, -50}, true):FadeOut(function()
						ui:Remove()
					end)
				end
			end)
			JH.Animate(hImageview, 200):Pos({0, -50}):FadeIn()
			hImageview:RegisterEvent(2048)
			hImageview:SetDragArea(0, 0, sW, sH)
			hImageview:EnableDrag(true)
			hImageview.OnFrameDragEnd = function()
				this.lock = true
			end
			hImageview.OnMouseWheel = function()
				local nDelta = Station.GetMessageWheelDelta()
				if nDelta < 0 then
					if hImageview.fScale < 1.3 then
						hImageview.fScale = hImageview.fScale + 0.05
					end
				else
					if hImageview.fScale > 0.3 then
						hImageview.fScale = hImageview.fScale - 0.05
					end
				end
				local nW, nH = fW * hImageview.fScale, fH * hImageview.fScale
				ui:Size(math.max(nW + 20, 150), nH + 40)
				img:Size(nW, nH)
				hImageview:SetDragArea(0, 0, nW, nH)
				hImageview:EnableDrag(true)
				return true
			end
		end
		item:GetParent():FormatAllItemPos()
	end
end

function Achievement.Send()
	if Achievement.IsOpened() then
		local frame = Achievement.GetFrame()
		local edit = frame:Lookup("Edit_EditMode")
		local desc = edit:GetText()
		if string.len(JH.UrlEncode(desc)) > 1200 or string.len(desc) < 5 then
			return JH.Alert(_L["game limit"])
		end
		local tParam = {
			aid    = frame.dwAchievement,
			desc   = desc,
			author = GetUserRoleName() .. "@" .. select(6, GetUserServer()), -- 每天跌停@长白山
			_      = GetCurrentTime(),
			lang   = ACHI_CLIENT_LANG
		}
		local t = {}
		for k, v in pairs(tParam) do
			table.insert(t, k .. "=" .. JH.UrlEncode(tostring(v)))
		end
		frame:Lookup("Btn_Send"):Enable(false)
		JH.RemoteRequest(ACHI_ROOT_URL .. "send/?" .. table.concat(t, "&"), function(szTitle, szDoc)
			frame:Lookup("Btn_Send"):Enable(true)
			local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
			if err then
				JH.Sysmsg2(_L["request failed"])
			else
				Achievement.EditMode(false)
				JH.Alert(result.msg)
			end
		end)
	end
end

function Achievement.EditMode(bEnter)
	if Achievement.IsOpened() then
		local frame = Achievement.GetFrame()
		if bEnter then
			frame:Lookup("WndScroll_Pedia"):Hide()
			frame:Lookup("Btn_Edit"):Hide()
			frame:Lookup("Btn_Cancel"):Show()
			frame:Lookup("Btn_Send"):Show()
			frame:Lookup("Edit_EditMode"):Show()
			if frame.szText == "" then
				frame.szText = _L["Achi Default Templates"]
			end
			frame:Lookup("Edit_EditMode"):SetText(frame.szText)
			frame:Lookup("Btn_Send"):Enable(false)
		else
			frame:Lookup("WndScroll_Pedia"):Show()
			frame:Lookup("Btn_Edit"):Show()
			frame:Lookup("Btn_Cancel"):Hide()
			frame:Lookup("Btn_Send"):Hide()
			frame:Lookup("Edit_EditMode"):Hide()
		end
		frame.bEdit = bEnter
	end
end

function Achievement.UpdateAnchor(frame)
	frame:SetPoint(ACHI_ANCHOR.s, 0, 0, ACHI_ANCHOR.r, ACHI_ANCHOR.x, ACHI_ANCHOR.y)
end

function Achievement.ClosePanel()
	if Achievement.IsOpened() then
		Wnd.CloseWindow(Achievement.IsOpened())
		PlaySound(SOUND.UI_SOUND, g_sound.CloseFrame)
	end
end

function Achievement.IsOpened()
	return Station.Lookup("Normal/JH_Achievement")
end

function Achievement.GetFrame()
	if not Achievement.IsOpened() then
		Wnd.OpenWindow(JH.GetAddonInfo().szRootPath .. "JH_Achievement/ui/JH_Achievement.ini", "JH_Achievement")
	end
	return Achievement.IsOpened()
end

function Achievement.GetLinkScript(szLink)
	return [[
		this.OnItemLButtonClick = function()
			OpenInternetExplorer(]] .. EncodeComponentsString(szLink) .. [[)
		end
		this.OnItemMouseEnter = function()
			this:SetFontColor(255, 0, 0)
		end
		this.OnItemMouseLeave = function()
			this:SetFontColor(20, 150, 220)
		end
	]]
end

function Achievement.OpenEncyclopedia(dwID, dwIcon, szTitle, szDesc)
	local frame = Achievement.GetFrame()
	if frame.bEdit then
		JH.Alert(_L["Please exit edit mode"])
	else
		local handle = frame.handle
		frame.dwAchievement = dwID
		frame:BringToTop()
		frame.title:SetText(szTitle)
		frame.box:SetObjectIcon(dwIcon)
		frame.desc:SetText(szDesc)
		frame:Lookup("Btn_Edit"):Enable(false)
		frame.pedia:Clear()
		frame.link:SetText(_L("Link(Open URL):%s", ACHI_ROOT_URL .. "detail/" .. dwID))
		frame.link:AutoSize()
		frame.pedia:AppendItemFromString(GetFormatText(_L["Loading..."], 6))
		frame.pedia:FormatAllItemPos()
		PlaySound(SOUND.UI_SOUND, g_sound.OpenFrame)
		JH.RemoteRequest(ACHI_ROOT_URL .. "api?op=game&aid=" .. dwID .. "&_" .. GetCurrentTime() .. "&lang=" .. ACHI_CLIENT_LANG, function(szTitle, szDoc)
			if Achievement.IsOpened() then
				local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
				if err then
					JH.Sysmsg2(_L["request failed"])
				else
					frame:Lookup("Btn_Edit"):Enable(true)
					if tonumber(result['id']) == frame.dwAchievement then
						Achievement.RemoteCallBack(result)
					end
				end
			end
		end)
	end
end

function Achievement.RemoteCallBack(result)
	local frame = Achievement.GetFrame()
	frame.result = result -- 菜单用
	frame.pedia:Clear()
	if result.data then
		local dat = result.data
		local xml = {}
		for k, v in ipairs(dat.desc) do
			if v.type == "text" then
				tinsert(xml, GetFormatText(v.text, 6))
			elseif v.type == "span" then
				local r, g, b = unpack(v.text[1])
				tinsert(xml, GetFormatText(v.text[2], 6, r, g, b))
			elseif v.type == "image" then
				tinsert(xml, "<image>script=".. EncodeComponentsString("this.src=" .. EncodeComponentsString(v.text[1]))  .." </image>")
			elseif v.type == "a" then
				tinsert(xml, GetFormatText(v.text[2], 6, 20, 150, 220, 272, Achievement.GetLinkScript(v.text[1])))
			end
		end
		frame.pedia:AppendItemFromString(table.concat(xml))
		for i = frame.pedia:GetItemCount() - 1, 0, -1 do
			local item = frame.pedia:Lookup(i)
			if item and item:GetType() == 'Image' and item.FromRemoteFile then
				item:FromRemoteFile(item.src, true, function(e, a, b, c)
					if e and e:IsValid() then
						e.localsrc = b
						e:AutoSize()
					end
				end)
			end
		end
		frame.szText = GetPureText(table.concat(xml))
		frame.pedia:AppendItemFromString(GetFormatText("\n\n", 6))
		frame.pedia:AppendItemFromString(GetFormatText(_L["revise"], 172))
		frame.pedia:AppendItemFromString(GetFormatText(" " .. dat.ver .. "\n", 6))
		frame.pedia:AppendItemFromString(GetFormatText(_L["Author"], 172))
		frame.pedia:AppendItemFromString(GetFormatText(" " .. dat.author .. "\n", 6))
		frame.pedia:AppendItemFromString(GetFormatText(_L["Change time"], 172))
		local date = FormatTime("%Y/%m/%d %H:%M", tonumber(dat.dateline))
		frame.pedia:AppendItemFromString(GetFormatText(" " .. date, 6))
	else
		frame.pedia:AppendItemFromString(GetFormatText(result.desc, 6))
		frame.szText = ""
	end
	frame.pedia:FormatAllItemPos()
end

function Achievement.AppendBoxEvent(handle)
	for i = 0, handle:GetItemCount() -1 do
		local item = handle:Lookup(i)
		if item and item:IsValid() then
			local dwID = item.dwAchievement
			if dwID ~= item.__JH_Append then
				local hiDescribe = item:Lookup("Text_AchiDescribe")
				local hName = item:Lookup("Text_AchiName")
				local box = item:Lookup("Box_AchiBox")
				if dwID and box and hiDescribe and hName then
					box:RegisterEvent(272)
					box.OnItemMouseEnter = function()
						this:SetObjectMouseOver(true)
						local x, y = this:GetAbsPos()
						local w, h = this:GetSize()
						local xml   = {}
						table.insert(xml, GetFormatText(_L["Click for Achievepedia"], 41))
						if IsCtrlKeyDown() then
							table.insert(xml, GetFormatText("\n\n" .. g_tStrings.DEBUG_INFO_ITEM_TIP .. "\n", 102))
							table.insert(xml, GetFormatText("dwAchievement: " .. dwID, 102))
						end
						OutputTip(table.concat(xml), 300, { x, y, w, h })
					end
					box.OnItemMouseLeave = function()
						this:SetObjectMouseOver(false)
						HideTip()
					end
					box.OnItemLButtonClick = function()
						Achievement.OpenEncyclopedia(dwID, box:GetObjectIcon(), hName:GetText(), hiDescribe:GetText())
						return
					end
				end
				item.__JH_Append = dwID
			end
		end
	end
end

function Achievement.OnFrameBreathe()
	local handle = Station.Lookup("Normal/AchievementPanel/PageSet_Achievement/Page_Achievement/WndScroll_AShow", "")
	if handle then
		Achievement.AppendBoxEvent(handle)
	end
	local handle2 = Station.Lookup("Normal/AchievementPanel/PageSet_Achievement/Page_Summary/WndScroll_Summary/WndContainer_AchiPanel/PageSet_Achi/Page_Chi/PageSet_RecentAchi/Page_AlmostFinish", "")
	if handle2 then
		Achievement.AppendBoxEvent(handle2)
	end
	local handle3 = Station.Lookup("Normal/AchievementPanel/PageSet_Achievement/Page_Summary/WndScroll_Summary/WndContainer_AchiPanel/PageSet_Achi/Page_Chi/PageSet_RecentAchi/Page_Scene", "")
	if handle3 then
		Achievement.AppendBoxEvent(handle3)
	end
end

function Achievement.SyncAchiList(btn, fnCallBack)
	local me = GetClientPlayer()
	local id = me.GetGlobalID()
	-- if IsRemotePlayer(me.dwID) then
	-- 	return JH.Alert(g_tStrings.STR_REMOTE_NOT_TIP)
	-- end
	if btn then btn:Enable(false) end
	local bitmap, data, nPoint = GetAchievementList()
	local code = table.concat(bitmap)
	local nMax = 480
	local len  = math.ceil(code:len() / nMax)
	local tParam = {
		op     = 'sync',
		gid    = id,
		len    = len,
		name   = GetUserRoleName(),
		school = me.dwForceID,
		camp   = me.nCamp,
		point  = nPoint,
		server = select(6, GetUserServer()),
		_      = GetCurrentTime(),
		lang   = ACHI_CLIENT_LANG
	}
	local t = {}
	for k, v in pairs(tParam) do
		tinsert(t, k .. "=" .. JH.UrlEncode(tostring(v)))
	end
	JH.RemoteRequest(ACHI_ROOT_URL .. "api?" .. table.concat(t, "&"), function(szTitle, szDoc)
		local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
		if result.code == 200 then
			for i = 1, len do -- 队列发送 不用管顺序
				local c = string.sub(code, (i - 1) * nMax + 1, i * nMax)
				local tParam = {
					op   = 'sync',
					i    = i,
					gid  = id,
					code = c,
					_    = GetCurrentTime(),
					lang = ACHI_CLIENT_LANG
				}
				local t = {}
				for kk, vv in pairs(tParam) do
					tinsert(t, kk .. "=" .. JH.UrlEncode(tostring(vv)))
				end
				if i ~= len then
					JH.RemoteRequest(ACHI_ROOT_URL .. "api?" .. table.concat(t, "&"))
				else
					JH.RemoteRequest(ACHI_ROOT_URL .. "api?" .. table.concat(t, "&"), function(szTitle, szDoc)
						local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
						if result.code == 200 then
							if fnCallBack then
								fnCallBack()
							end
						end
					end)
				end
			end
		end
	end)
end

local PS = {}
function PS.OnPanelActive(frame)
	local ui, nX, nY = GUI(frame), 10, 0
	local me = GetClientPlayer()
	local id = me.GetGlobalID()
	nX, nY = ui:Append("Text", { x = 0, y = 0, txt = _L["Achievepedia"], font = 27 }):Pos_()
	ui:Append("Text", { x = 0, y = nY + 5, w = 520, h = 120 , multi = true, txt = _L["Achievepedia About"] })
	-- zhcn版本可用
	nY = 140
	if ACHI_CLIENT_LANG == "zhcn" or ACHI_CLIENT_LANG == "zhtw" then
		nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Sync Game Info"], font = 27 }):Pos_()
		-- name
		nX = ui:Append("Text", { x = 10, y = nY + 5 , txt = _L["Role Nmae:"], color = { 255, 255, 200 } }):Pos_()
		nX, nY = ui:Append("Text", { x = nX + 5, y = nY + 5 , txt = GetUserRoleName() }):Pos_()
		nX = ui:Append("Text", { x = 10, y = nY + 5 , txt = _L["Last Sync Time:"], color = { 255, 255, 200 } }):Pos_()
		nX, nY = ui:Append("Text", "time", { x = nX + 5, y = nY + 5 , txt = _L["loading..."] }):Pos_()
		-- get
		JH.RemoteRequest(ACHI_ROOT_URL .. "api?op=check&code=" .. id .. "&_" .. GetCurrentTime() .. "&lang=" .. ACHI_CLIENT_LANG, function(szTitle, szDoc)
			if ui then
				local result, err = JH.JsonDecode(JH.UrlDecode(szDoc))
				if err then
					ui:Fetch('time'):Text(_L["request failed"])
				else
					if result.code == 200 then
						ui:Fetch('time'):Text(FormatTime("%Y/%m/%d %H:%M:%S", tonumber(result.data.time)))
					else
						ui:Fetch('time'):Text(_L["No Record"])
					end
					ui:Fetch("sync"):Enable(true)
				end
			end
		end)
		nX, nY = ui:Append("WndButton3", "sync", { x = 0, y = nY + 15 , txt = _L["sync Achievement"], enable = false }):Click(function()
			Achievement.SyncAchiList(ui:Fetch('sync'), function()
				GetUserInput(_L["Synchronization Complete, Please copy the id."], nil, nil, nil, nil, id);
				ui:Fetch('sync'):Enable(true)
				ui:Fetch('time'):Text(FormatTime("%Y/%m/%d %H:%M:%S", GetCurrentTime()))
			end)
		end):Pos_()
	end
	nX, nY = ui:Append("Text", { x = 0, y = nY, txt = _L["Other"], font = 27 }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 10 , txt = _L["Achievepedia Website"], color = { 255, 255, 200 } }):Pos_()
	nX, nY = ui:Append("WndEdit", { x = 120, y = nY + 10 , txt = "http://www.j3ui.com/wiki" }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 5 , txt = _L["QQ Group"], color = { 255, 255, 200 } }):Pos_()
	nX, nY = ui:Append("WndEdit", { x = 120, y = nY + 5 , txt = "256907822" }):Pos_()
	nX = ui:Append("Text", { x = 10, y = nY + 5 , txt = _L["Global ID"], color = { 255, 255, 200 } }):Pos_()
	nX, nY = ui:Append("WndEdit", { x = 120, y = nY + 5 , txt = id }):Pos_()
	-- wechat
	ui:Append("Image", { x = 340, y = 260, h = 150, w = 150, file = JH.GetAddonInfo().szRootPath .. "JH_Achievement/ui/qrcode_for_j3wikis.tga" })
end


GUI.RegisterPanel(_L["Achievepedia"], 3151, g_tStrings.CHANNEL_CHANNEL, PS)

-- kill AchievementPanel
if Station and Station.Lookup("Normal/AchievementPanel") then
	Wnd.CloseWindow("AchievementPanel")
end

-- init
JH.RegisterEvent("ON_FRAME_CREATE.ACHIVEEMENT", function()
	if arg0 and arg0:GetName() == "AchievementPanel" then
		arg0.OnFrameShow = function()
			JH.BreatheCall("ACHIVEEMENT", Achievement.OnFrameBreathe)
			JH.Debug("Init ACHIVEEMENT")
		end
		arg0.OnFrameHide = function()
			JH.BreatheCall("ACHIVEEMENT")
			JH.Debug("UnInit ACHIVEEMENT")
		end
		JH.BreatheCall("ACHIVEEMENT", Achievement.OnFrameBreathe)
		JH.UnRegisterEvent("ON_FRAME_CREATE.ACHIVEEMENT")
	end
end)
