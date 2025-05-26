GLOBAL.setmetatable(env, {
    __index = function(_, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})

local lang = GetModConfigData("lang") or "auto"
if lang == "auto" then
    lang = GLOBAL.LanguageTranslator.defaultlang
end

local chinese_languages =
{
    zh = "zh", -- Chinese for Steam
    zhr = "zh", -- Chinese for WeGame
    ch = "zh", -- Chinese mod
    chs = "zh", -- Chinese mod
    sc = "zh", -- simple Chinese
    zht = "zh", -- traditional Chinese for Steam
	tc = "zh", -- traditional Chinese
	cht = "zh", -- Chinese mod
}

if chinese_languages[lang] ~= nil then
    lang = chinese_languages[lang]
else
    lang = "en"
end

local function UpdateModSettings(mod_list)
    print("更新数据......")
    local modconfig = KnownModIndex:LoadModConfigurationOptions(modname)
    for _,j in pairs (modconfig) do
        if j.name == "client_mods_list" then
            j.saved = mod_list
        end
    end

    KnownModIndex:SaveConfigurationOptions(function() end, modname, modconfig, false)
end

local mod_list = {}
local function fn(self)
    local ImageButton = require "widgets/imagebutton"
    if ShardSaveGameIndex then
        mod_list =  ShardSaveGameIndex.slot_cache and
                    ShardSaveGameIndex.slot_cache[self.save_slot] and
                    ShardSaveGameIndex.slot_cache[self.save_slot]["Master"] and
                    ShardSaveGameIndex.slot_cache[self.save_slot]["Master"].enabled_mods and
                    ShardSaveGameIndex.slot_cache[self.save_slot]["Master"].enabled_mods[modname] and
                    ShardSaveGameIndex.slot_cache[self.save_slot]["Master"].enabled_mods[modname].configuration_options and
                    ShardSaveGameIndex.slot_cache[self.save_slot]["Master"].enabled_mods[modname].configuration_options["client_mods_list"] or {}
    end

    if (self.world_tabs[2] and self.world_tabs[2].isnewshard == true) then
        mod_list = {} -- 清空列表
        print("[客户端MOD转为服务器MOD] 请成功生成洞穴世界后再使用此Mod，本MOD不兼容无洞穴存档\n[Convert client mod to server mod] Please successfully generate the cave world before using this Mod.")
        return
    end

    print("[客户端MOD转为服务器MOD] 自动更新数据...")
    for k,_ in pairs(mod_list) do
        print("要转换为服务器的客户端MOD：",k, "版本号：",KnownModIndex:InitializeModInfo(k).version)

        local known_mod = KnownModIndex.savedata.known_mods[k]
        local temp_config = {}
        local mod_options = known_mod.modinfo.configuration_options
        for k,v in pairs(mod_options) do
            if type(v) == "table" then
                temp_config[v.name] = mod_options[k].saved or v.default
            end
        end

        mod_list[k] = {
                version = KnownModIndex:InitializeModInfo(k).version, -- "workshop-123456" = 版本号
                config = temp_config
        }
    end

    local _ApplyDataToWidget = self.mods_tab.mods_scroll_list.update_fn
    self.mods_tab.mods_scroll_list.update_fn = function(context, widget, data, index)
        _ApplyDataToWidget(context, widget, data, index)
        if data == nil then return end
        if KnownModIndex:IsModEnabledAny("workshop-2657513551") then
            if not tips_DSA then
                tips_DSA = true
                mod_list = {} -- 清空列表
                print("[客户端MOD转为服务器MOD] 请关闭独行长路后再使用此Mod（一个人玩还开这个干嘛???）\n[Convert client mod to server mod] Please disable Don't Starve Alone before using this Mod")
            end
            return
        end

        local opt = widget.moditem
        local function refresh()
            if mod_list[opt.parent.data.mod.modname] then
                opt.add_to_server_mod:SetTextures("images/ui.xml", "checkbox_on.tex", "checkbox_on_highlight.tex", "checkbox_on_disabled.tex", nil, nil, {1,1}, {0,0}) --打勾状态
            else
                opt.add_to_server_mod:SetTextures("images/ui.xml", "checkbox_off.tex", "checkbox_off_highlight.tex", "checkbox_off_disabled.tex", nil, nil, {1,1}, {0,0}) -- 不打勾状态
            end
        end

        if opt.add_to_server_mod == nil then -- 如果没创建按钮
            if self.mods_tab.currentmodtype == "client" then -- 仅在客户端模组列表页面添加按钮
                opt.add_to_server_mod = opt:AddChild(ImageButton("images/ui.xml", "checkbox_off.tex", "checkbox_off_highlight.tex", "checkbox_off_disabled.tex", nil, nil, {1,1}, {0,0}))
                opt.add_to_server_mod:SetPosition(140, 20, 0)
                opt.add_to_server_mod:SetHoverText(lang == "zh" and "添加至服务器模组列表(所有玩家都会加载此模组,服务器不会加载)" or "Add to server mod list (all players will load this mod, but the server will not).")
                opt.add_to_server_mod:SetOnClick(function() -- 按下按钮后
                    if mod_list[opt.parent.data.mod.modname] then
                        mod_list[opt.parent.data.mod.modname] = nil
                    else
                        local known_mod = KnownModIndex.savedata.known_mods[opt.parent.data.mod.modname]
                        local temp_config = {}
                        local mod_options = known_mod.modinfo.configuration_options
                        for k,v in pairs(mod_options) do
                            if type(v) == "table" then
                                temp_config[v.name] = mod_options[k].saved or v.default
                            end
                        end

                        mod_list[opt.parent.data.mod.modname] = {
                             version = KnownModIndex:InitializeModInfo(opt.parent.data.mod.modname).version, -- "workshop-123456" = 版本号
                             config = temp_config
                        }
                    end
                    refresh() -- 切换开关状态也需要刷新
                end)

                local oldCreate = self.Create
                self.Create = function(self, warnedOffline, warnedDisabledMods, warnedOutOfDateMods, ...)
                    for k,v in pairs(mod_list) do
                        local known_mod = KnownModIndex.savedata.known_mods[k]
                        local temp_config = {}
                        local mod_options = known_mod.modinfo.configuration_options
                        for k1,v1 in pairs(mod_options) do
                            if type(v1) == "table" then
                                temp_config[v1.name] = mod_options[k1].saved or v1.default
                            end
                        end

                        mod_list[k] = {
                             version = KnownModIndex:InitializeModInfo(k).version, -- "workshop-123456" = 版本号
                             config = temp_config
                        }
                    end
                    UpdateModSettings(mod_list)
                    oldCreate(self, warnedOffline, warnedDisabledMods, warnedOutOfDateMods, ...)
                end

                opt.add_to_server_mod:MoveToFront()
                opt.add_to_server_mod.scale_on_focus = false
            end
        elseif opt.add_to_server_mod and self.mods_tab.currentmodtype == "client" then -- 客户端模组页面
            opt.add_to_server_mod:Show() -- 显示按钮
        elseif opt.add_to_server_mod and self.mods_tab.currentmodtype == "server" then -- 服务器模组页面
            opt.add_to_server_mod:Hide() -- 隐藏按钮
        end

        if opt.add_to_server_mod then
            refresh() -- 实时刷新
        end
    end
end

-- 修改创建世界界面, 这里需要延迟1帧等待界面生成, 由modworldgenmain触发
if rawget(GLOBAL, "TheFrontEnd") ~= nil then
	scheduler:ExecuteInTime(0, function()
		for _, screen in ipairs(GLOBAL.TheFrontEnd.screenstack) do
			if screen.name == "ServerCreationScreen" then
				fn(screen)
				break
			end
		end
	end)
end