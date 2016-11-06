SLASH_NKEYSTONE1 = '/nklist';
SLASH_NKEYSTONE2 = '/nk';

NKeystone = {
	AddonPrefix = "NKEYSTONE",
	KeystoneItemID = 138019,
	RequestInfoTag = "NKEYSTONEREQUESTINFO",
	RequestMaxLevelTag = "NKEYSTONEREQUESTMAXLEVEL",
	NoCompletionsThisWeek = "No Mythic+ completions during this reset"
};

local nkt = NKeystone;

RegisterAddonMessagePrefix(nkt.AddonPrefix);

function SlashCmdList.NKEYSTONE(msg, editbox)
	if msg == "keystones" then
		GetKeystoneInfo();
	elseif msg == "maxlevel" then
		GetMaxLevel();
	else
		print("NKeystone");
		print("  /nk keystones");
		print("  /nk maxlevel");
	end
end

function GetMythicSummary()
	local maxLevel, mapID = GetMythicDetails()
	if maxLevel and mapID then
		return "Max level: " .. maxLevel .. " on map: " .. mapID;
	else
		return nkt.NoCompletionsThisWeek;
	end
end

function GetMythicDetails()
	maps = { };
	C_ChallengeMode.GetMapTable(maps);
	maxLevel = 0;
	mapID = nil;
	for i = 1, #maps do
		local _, _, level = C_ChallengeMode.GetMapPlayerStats(maps[i]);
		if level and level > maxLevel then
			maxLevel = level;
			mapID = maps[i];
		end
	end
	return maxLevel, mapID
end

function GetMaxLevel()
	print("NK: Requesting Max Level");
	SendAddonMessage(nkt.AddonPrefix, nkt.RequestMaxLevelTag, "GUILD");
end

function GetKeystoneInfo()
	print("NK: Requesting Keystone Info");
	SendAddonMessage(nkt.AddonPrefix, nkt.RequestInfoTag, "GUILD");
end

local function filter(msg, ...)
	local poorColor = select(4, GetItemQualityColor(LE_ITEM_QUALITY_POOR))
	local epicColor = select(4, GetItemQualityColor(LE_ITEM_QUALITY_EPIC))
	local msg2 = msg:gsub("(|c"..epicColor.."|Hitem:138019:([0-9:]+)|h(%b[])|h|r)", function(msg, itemString, itemName)
		local info = { strsplit(":", itemString) }
		local mapID = tonumber(info[13])
		local mapLevel = tonumber(info[14])
		if not mapID or not mapLevel then return msg end
	
		local offset = 15
		if mapLevel >= 4 then offset = offset + 1 end
		if mapLevel >= 7 then offset = offset + 1 end
		if mapLevel >= 10 then offset = offset + 1 end
		local depleted = info[offset] ~= "1"
	
		if depleted then
			return msg:gsub("|c"..epicColor, "|c"..poorColor)
		else
			return msg
		end
	end)
	msg2 = msg2:gsub("(|Hitem:138019:([0-9:]+)|h(%b[])|h)", function(msg, itemString, itemName)
		local info = { strsplit(":", itemString) }
		local mapID = tonumber(info[13])
		local mapLevel = tonumber(info[14])
	
		if mapID and mapLevel then
			local mapName = C_ChallengeMode.GetMapInfo(mapID)
			local keystoneFormat = "[Keystone: %s - Level %d]"
			return msg:gsub(itemName:gsub("(%W)","%%%1"), format(keystoneFormat, mapName, mapLevel))
		else
			return msg
		end
	end)
	if msg2 ~= msg then
		return msg2, ...
	end
end

function SendKeystoneInfo(target)
	local bagID, slotID = GetBagAndSlotIDForKeystone();
	local itemLink = GetItemLinkFromBagAndSlotID(bagID, slotID);
	if itemLink ~= nil then
		dist = target and "WHISPER" or "GUILD";
		SendAddonMessage(nkt.AddonPrefix, itemLink, dist, target);
	end
end

function SendMaxLevel(target)
	local mythicSummary = GetMythicSummary();
	dist = target and "WHISPER" or "GUILD";
	SendAddonMessage(nkt.AddonPrefix, mythicSummary, dist, target);
end

function GetBagAndSlotIDForKeystone()
	for bagID = 0, NUM_BAG_SLOTS do
		local slotCount = GetContainerNumSlots(bagID);
		for slotID = 0, slotCount do
			local itemID = GetContainerItemID(bagID, slotID);
			if itemID == nkt.KeystoneItemID then
				return bagID, slotID;
			end
		end
	end
	return nil;
end

function GetItemLinkFromBagAndSlotID(bagID, slotID)
	if bagID == nil or slotID == nil then
		return nil;
	end

	local texture, itemCount, locked, quality, readable, lootable, itemLink
		= GetContainerItemInfo(bagID, slotID);
	return itemLink;
end

function GetItemStringFromItemLink(itemLink)
	return select(3, strfind(itemLink, "|H(.+)|h"));
end

function HandleAddonMsg(msg)
	-- First try to parse this as an itemlink
	local _, newLink = GetItemInfo(msg);
	if newLink ~= nil then
		thisLink = filter(newLink);
		return thisLink;
	end

	-- If that doesn't work then check for not completing anything
	if msg == nkt.NoCompletionsThisWeek then
		return nkt.NoCompletionsThisWeek;
	end

	-- Then try to parse for maxlevel and mapname
	local maxLevel, mapID = string.match(msg, "Max level: (%d) on map: (.+)");
	if maxLevel ~= nil and mapID ~= nil then
		if type(mapID) == "number" then
			local mapName = C_ChallengeMode.GetMapInfo(mapID);
			return "Max level: " .. maxLevel .. " on map: " .. mapName;
		else
			return "Max level: " .. maxLevel;
		end
	end

	-- Can't parse, just return nothing
	return nil;
end

local eventFrame = CreateFrame("FRAME");
eventFrame:RegisterEvent("CHAT_MSG_ADDON");
eventFrame:SetScript("OnEvent", function(...) nkt.OnEvent(...); end);

nkt.OnEvent = function(self, event, ...)
	C_ChallengeMode.RequestMapInfo();
	if event == "CHAT_MSG_ADDON" then
		local prefix, msg, dist, sender = ...;
		if prefix == nkt.AddonPrefix then
			if msg == nkt.RequestInfoTag then
				SendKeystoneInfo(sender);
			elseif msg == nkt.RequestMaxLevelTag then
				SendMaxLevel(sender);
			else
				if dist == "WHISPER" then
					parsedMsg = HandleAddonMsg(msg);
					if parsedMsg ~= nil then
						print("NK: " .. sender .. ": " .. parsedMsg);
					end
				end
			end
		end
	end
end