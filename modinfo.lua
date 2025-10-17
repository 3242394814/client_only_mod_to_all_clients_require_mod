---@diagnostic disable: lowercase-global
local function zh_en(zh, en)  -- Other languages don't work
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

    if chinese_languages[locale] ~= nil then
        lang = chinese_languages[locale]
    else
        lang = en
    end

    return lang ~= "zh" and en or zh
end

name = zh_en("客户端Mod转为服务器Mod", "Convert client mod to server mod")
author = "冰冰羊"
description = [[

]]
version = "0.3"
dst_compatible = true
forge_compatible = true
gorge_compatible = true
dont_starve_compatible = false
client_only_mod = false
all_clients_require_mod = true
icon_atlas = "images/modicon.xml"
icon = "modicon.tex"
forumthread = ""
api_version_dst = 10
priority = 2e65
-- mod_dependencies = {}
server_filter_tags = {"客户端Mod转为服务器Mod","Convert client mod to server mod"}
configuration_options =
{
    {
        name = "client_mods_list",
        label = "",
        hover = "",
        options = {
            {description = "", data = {}},
        },
        default = {},
    },
    {
        name = "DEBUG_print",
        label = zh_en("打印调试信息", "Print Debug Info"),
        hover = zh_en("在客户端日志中打印调试信息", "Print debug information in client log(But they are in Chinese)"),
        options = {
            {description = zh_en("开启", "On"), data = true},
            {description = zh_en("关闭", "Off"), data = false},
        },
        default = false,
        client = true,
    },
    {
        name = "language",
        label = zh_en("语言", "Language"),
        hover = zh_en("选择你想要使用的语言", "Select the language you want to use"),
        options =
        {
            {description = "English(英语)", data = "en", hover = ""},
            {description = "中文(Chinese)", data = "zh", hover = ""},
            {description = zh_en("自动", "Auto"), data = "auto", hover = zh_en("根据游戏语言自动设置", "Automatically set according to the game language")},
        },
        default = "auto",
    },
}