GLOBAL.setmetatable(env, {
    __index = function(_, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})

local function DEBUG_print(...)
    if GetModConfigData("DEBUG_print") then
        print(...)
    end
end

local clientmods = GetModConfigData("client_mods_list") or {}

if not TheNet:GetIsClient() then
    local OldGetEnabledServerModNames = ModManager.GetEnabledServerModNames
    ModManager.GetEnabledServerModNames=function(self,...)
        local server_mods = OldGetEnabledServerModNames(self,...)
            if IsNotConsole() then
                for k,v in pairs(clientmods) do
                    table.insert(server_mods, k)
                end
            end
        return server_mods
    end
end

-- 额外处理
for k,_ in pairs(clientmods) do
    if not KnownModIndex.savedata.known_mods[k] then
        DEBUG_print("[客户端MOD转为服务器MOD] " .. k .. "未下载，使用方法一转换MOD类型")
        KnownModIndex.savedata.known_mods[k] = {}
        local known_mod = KnownModIndex.savedata.known_mods[k]
        known_mod.modinfo = {
            all_clients_require_mod = true,
            client_only_mod = false,
            version = clientmods[k].version,
        }
    elseif KnownModIndex.savedata.known_mods[k] and KnownModIndex.savedata.known_mods[k].modinfo then
        DEBUG_print("[客户端MOD转为服务器MOD] MOD已下载，使用方法二转换MOD类型", k," = ",clientmods[k].version)
        KnownModIndex.savedata.known_mods[k].modinfo.all_clients_require_mod = true
        KnownModIndex.savedata.known_mods[k].modinfo.client_only_mod = false
    end

    -- 被添加至服务器的客户端MOD，如果有设置过就加载自己设置的选项，否则加载服务器提供的选项，否则加载默认选项
    local known_mod = KnownModIndex.savedata.known_mods[k]
    if known_mod and known_mod.modinfo then
        if not known_mod.modinfo.configuration_options then -- MOD未下载的情况（仅服务器可能会走这条分支，客户端未下载MOD就完全不生效了）
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
            local mod_options = known_mod.modinfo.configuration_options
            for _,k1 in pairs(mod_options) do
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
                for _,k1 in pairs(mod_options) do
                    temp_options[k1.name] = k1.saved or temp_options[k1.name] or k1.default -- 本地保存的设置/服务器设置/默认设置
                    DEBUG_print("[客户端MOD转为服务器MOD] 正在修改临时模组设置", k, k1.name, "=", temp_options[k1.name])
                end
            end
        end
    end
end
--总流程大概是：client_only_mod 转换为 all_clients_require_mod →服务器设置好客户端MOD配置→客户端进服先使用服务器提供的客户端MOD配置→客户端再使用自己生成的客户端MOD配置


-- 笔记部分，Table表的格式大概长这样
--[[
mod_options = {
    {
        name = "custom_name_1",
        label = "",
        default = "",
        options = {
            {
                data = "",
                description = "",
            },
        },
        saved = "value1"
        saved_client = ""
    },
    {
        name = "custom_name_2",
        label = "",
        default = "",
        options = {
            {
                data = "",
                description = "",
            },
        },
        saved = "value2"
        saved_client = ""
    },
}

temp_options = {
    custom_name_1 = "value1",
    custom_name_2 = "value2",
    custom_name_3 = "value3",
}
]]