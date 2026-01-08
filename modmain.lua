GLOBAL.setmetatable(env, {
    __index = function(_, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})

-- 不支持独行长路/无洞穴世界
if not TheNet:IsDedicated() and not TheNet:GetIsClient() then
    AddPrefabPostInit("world", function(inst)
        if TheNet:GetIsServer() then
            inst:DoTaskInTime(3, function()
                c_announce("[客户端MOD转为服务器MOD] 检测到当前服务器 未开启洞穴世界 或 开启了独行长路Mod，本模组停止运行！")
                c_announce("[Convert client mod to server mod] The current server was detected to have Cave World disabled or Don't Starve Alone mod enabled. This mod has stopped running!")
            end)
        end
    end)
    return
end

-- 检测环境
-- print("专服 = ",TheNet:IsDedicated()) -- 专服始终为true，反之始终false
-- print("服务器 = ",TheNet:GetIsServer()) -- 专服初始化时为false，然后为true。使用客户端开服始终为true （客户端开服指开了独行长路的世界/无洞穴世界）
-- print("客户端 = ",TheNet:GetIsClient()) -- 客户端始终为true，反之始终false
-- if true then return end

local DEBUG_print = GetModConfigData("DEBUGPrint", true) and print or function(...) end
local clientmods = GetModConfigData("client_mods_list") or {}

if TheNet:IsDedicated() then -- 服务器：将转换的客户端模组添加到“服务器模组列表”中，这样客户端进服时就会自动下载并启用那些客户端模组
    local OldGetEnabledServerModNames = ModManager.GetEnabledServerModNames
    ModManager.GetEnabledServerModNames = function(self,...)
        local server_mods = OldGetEnabledServerModNames(self,...)
            if IsNotConsole() then
                for k,v in pairs(clientmods) do
                    if not table.contains(server_mods, k) then
                        table.insert(server_mods, k)
                    end
                end
            end
        return server_mods
    end
else -- 客户端，检查是否下载并正确开启了所需的客户端模组
    for k in pairs(clientmods) do
        if not (KnownModIndex:GetModInfo(k) and KnownModIndex:IsModTempEnabled(k)) then
            return -- 缺斤少两！取消加载本模组！可能是服务器为独行长路/无洞穴世界，所以服务器没将模组添加到服务器模组列表，所以玩家不会临时启用那些客户端模组，所以这里检测不通过
        end
    end
end

local ServerAreClientModsDisabled = false -- 服务器是否开启“友好的禁用客户端模组”
local need_kleiregistermods = {} -- 需要注册的客户端模组

-- 检测服务器是否开启“友好的禁用客户端模组”
local server_listing = TheNet:GetServerListing()
if server_listing and server_listing.client_mods_disabled then
    ServerAreClientModsDisabled = true
end

-- Sort the mods by priority, so that "library" mods can load first
local function sanitizepriority(priority)
    local prioritytype = type(priority)
    if prioritytype == "string" then
        return tonumber(priority) or 0
    elseif prioritytype == "number" then
        return priority
    end
    return 0
end
local function modPrioritySort(a, b)
    -- NOTES(JBK): Mac OS changed locale sorting so we have to do this using stringidsorter to avoid locale issues.
    -- I am also changing how it is sorted if the modinfo is not present to use the mod's modname instead.
    -- All priority fields are going to be converted to a number.
    if a.modinfo and b.modinfo then
        local apriority = sanitizepriority(a.modinfo.priority)
        local bpriority = sanitizepriority(b.modinfo.priority)
        if apriority == bpriority then
            local aname = a.modinfo.name
            if type(aname) ~= "string" then
                aname = a.modname
            end
            local bname = b.modinfo.name
            if type(bname) ~= "string" then
                bname = b.modname
            end
            return stringidsorter(aname, bname)
        end
        return apriority > bpriority
    end
    return stringidsorter(a.modname, b.modname)
end
local function insert_sorted(tbl, value)
    for i = 1, #tbl do
        if modPrioritySort(value, tbl[i]) then
            table.insert(tbl, i, value)
            return
        end
    end
    table.insert(tbl, value)
end

local function registerclientmods(modname) -- 手动初始化客户端模组并添加到模组加载列表中
    if not table.contains(ModManager.modnames, modname) and ModManager.worldgen == false or (ModManager.worldgen == true and KnownModIndex:IsModCompatibleWithMode(modname)) then
        DEBUG_print("[客户端MOD转为服务器MOD] 加载客户端模组：", modname)
        table.insert(ModManager.modnames, modname)

        if ModManager.worldgen == false then
            -- Make sure we load the config data before the mod (but not during worldgen)
            if TheNet:GetIsServer() and not TheNet:IsDedicated() then
                local options = KnownModIndex:LoadModConfigurationOptions(modname, false)

                KnownModIndex:SetTempModConfigData({[modname] = options})

                KnownModIndex:LoadModConfigurationOptions(modname, true)
            else
                KnownModIndex:LoadModConfigurationOptions(modname, not TheNet:GetIsServer())
            end
        end

        local initenv = KnownModIndex:GetModInfo(modname)
        local env = CreateEnvironment(modname,  ModManager.worldgen)
        env.modinfo = initenv

        -- table.insert( ModManager.mods, env ) -- 将模组添加到饥荒需要加载的模组列表中
        insert_sorted(ModManager.mods, env) -- 根据模组加载优先级插入到正确位置
        table.insert( need_kleiregistermods, env )
        local loadmsg = "Loading mod: "..ModInfoname(modname).." Version:"..env.modinfo.version
        if initenv.modinfo_message and initenv.modinfo_message ~= "" then
            loadmsg = loadmsg .. " ("..initenv.modinfo_message..")"
        end
        print(loadmsg)
    end
end

-- 额外处理
for k in pairs(clientmods) do
    if not KnownModIndex.savedata.known_mods[k] and TheNet:IsDedicated() then -- 只有专服才能使用方法一
        DEBUG_print("[客户端MOD转为服务器MOD] 使用方法一转换MOD类型", k)
        KnownModIndex.savedata.known_mods[k] = {}
        local known_mod = KnownModIndex.savedata.known_mods[k]
        known_mod.modinfo = {
            all_clients_require_mod = true,
            client_only_mod = false,
            version = clientmods[k].version,
        }
    elseif KnownModIndex.savedata.known_mods[k] and KnownModIndex.savedata.known_mods[k].modinfo then
        DEBUG_print("[客户端MOD转为服务器MOD] 使用方法二转换MOD类型", k," = ",clientmods[k].version)
        KnownModIndex.savedata.known_mods[k].modinfo.all_clients_require_mod = true
        KnownModIndex.savedata.known_mods[k].modinfo.client_only_mod = false
        KnownModIndex.savedata.known_mods[k].temp_disabled = false -- 使Chinese++ Pro能够正确判断其它客户端模组是否开启
    end

    -- 被添加至服务器的客户端MOD，如果有设置过就加载自己设置的选项，否则加载服务器提供的选项，否则加载默认选项
    local known_mod = KnownModIndex.savedata.known_mods[k]
    if known_mod and known_mod.modinfo then
        if not known_mod.modinfo.configuration_options then -- MOD未下载的情况（仅服务器可能会走这条分支）
            known_mod.modinfo.configuration_options = {}
            local mod_options = known_mod.modinfo.configuration_options
            for k1,v1 in pairs(clientmods[k].config) do
                table.insert(mod_options,{
                    name = k1,
                    saved = v1 -- 未下载对应客户端Mod的情况下，仅使用来自本Mod设置的配置
                })
                DEBUG_print("[客户端MOD转为服务器MOD] 正在使用方法一设置客户端模组设置", k, k1, "=", v1)
            end
        else -- MOD已下载的情况
            KnownModIndex:LoadModConfigurationOptions(k) -- 加载保存的模组设置文件
            local mod_options = known_mod.modinfo.configuration_options
            for _, k1 in pairs(mod_options) do
                for k2,v2 in pairs(clientmods[k].config) do
                    if k1.name == k2 then
                        k1.saved = k1.saved or v2 or k1.default -- 本地保存的设置/服务器设置/默认设置
                        DEBUG_print("[客户端MOD转为服务器MOD] 正在使用方法二设置客户端模组设置", k, k1.name, "=", k1.saved)
                        break
                    end
                end
            end

            if known_mod.temp_config_options then -- 给客户端执行的
                local temp_options = known_mod.temp_config_options
                for _, k1 in pairs(mod_options) do
                    if type(k1) == "table" and k1.name then
                        temp_options[k1.name] = k1.saved or temp_options[k1.name] or k1.default -- 本地保存的设置/服务器设置/默认设置
                        DEBUG_print("[客户端MOD转为服务器MOD] 正在修改临时模组设置", k, k1.name, "=", temp_options[k1.name])
                    else
                        DEBUG_print("[客户端MOD转为服务器MOD] 修改临时模组设置时出错，k = " .. tostring(k) , "type(k1) = " .. tostring(type(k1)), "值为" .. tostring(k1))
                    end
                end
            end
        end
    end

    -- 兼容"友好的禁用客户端模组" (手动在此处加载被转换的客户端模组)
    if TheNet:GetIsClient() then
        if ServerAreClientModsDisabled then
            DEBUG_print("[客户端MOD转为服务器MOD] 检测到服务器开启了“友好的禁用客户端模组”  开始进行额外处理")
            registerclientmods(k)
        end
    end
end

if TheNet:GetIsClient() and ServerAreClientModsDisabled then
    -- 修复Chinese++ Pro不加载的问题（修复代码总不能写Chinese++ Pro里吧，它都不加载了修个寂寞）
    if server_listing and server_listing.mods_description then
        for k,v in pairs (server_listing.mods_description) do
            if server_listing.mods_description[k].modinfo_name == "Chinese++ Pro" or server_listing.mods_description[k].modinfo_name == "Chinese++ Pro - GitLab版" then
                registerclientmods(server_listing.mods_description[k].mod_name)
                break
            end
        end
    end

    kleiregistermods(need_kleiregistermods) -- 使用科雷的C层函数注册模组
end

if TheNet:GetIsClient() then
    -- 修复部分行为不一致的问题

    local _ModIndex_IsModEnabled = KnownModIndex.IsModEnabled
    KnownModIndex.IsModEnabled = function(self, modname, ...)
        local mod_enabled = _ModIndex_IsModEnabled(self, modname, ...)
        return mod_enabled or clientmods[modname]
    end

    local _GetModConfigurationOptions_Internal = KnownModIndex.GetModConfigurationOptions_Internal
    KnownModIndex.GetModConfigurationOptions_Internal = function(self, modname, force_local_options, ...)
        return _GetModConfigurationOptions_Internal(self, modname, force_local_options or clientmods[modname], ...)
    end
end