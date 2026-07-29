--[[
    This user patch is for use with the Project: Title plugin.
    It requires v3.5.

    Based on 2-pt-modify-series-format.lua. Extends series display with
    optional subseries (and index) from EPUB calibre metadata (#subseries).
    Shows: "Series [index] • Subseries [index]" using the same format for both.
    If a book has no subseries (missing or empty in OPF), only series is shown;
    no bullet and no subseries text are added.

    - Series/subseries data: from BookInfoManager (series) and from EPUB OPF
      (calibre:user_metadata:#subseries) when not already in bookinfo.
    - Format: Same placeholders as 2-pt-modify-series-format ({index}, {series});
      subseries is formatted identically and separated by a bullet (•).

    Author: (based on Andreas Lösel's 2-pt-modify-series-format.lua)
    License: GNU AGPL v3
--]]

-- vvvvvvvvvvvvvvvvvvvvvvvvvvv-Modify here-vvvvvvvvvvvvvvvvvvvvvvvvvvvvv -

-- Same format options as 2-pt-modify-series-format.lua
-- Available placeholders: {index}, {series}
local FORMAT_DEFAULT     = "#{index} - {series}"      -- #3 - The Lord of the Rings
local FORMAT_COLON       = "#{index}: {series}"       -- #3: The Lord of the Rings
local FORMAT_REVERSE     = "{series} #{index}"        -- The Lord of the Rings #3
local FORMAT_BRACKET     = "{series} [{index}]"       -- The Lord of the Rings [3]
local FORMAT_BOOK        = "Book {index} of {series}" -- Book 3 of The Lord of the Rings
local FORMAT_VOL         = "Vol. {index} - {series}"  -- Vol. 3 - The Lord of the Rings
local FORMAT_SERIES_ONLY = "{series}"                 -- The Lord of the Rings

local SERIES_FORMAT      = FORMAT_BRACKET

-- Bullet between series and subseries (• = U+2022); only shown when subseries is present
local SERIES_SUBSERIES_SEP = " • "

-- ^^^^^^^^^^^^^^^^^^^^^^^^^^^-Modify here-^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ -


local userpatch = require("userpatch")

-- Escape a string for safe use in shell commands (POSIX)
local function escapeShellArg(arg)
    return "'" .. arg:gsub("'", "'\\''") .. "'"
end

local function patchCoverBrowser(plugin)
    local logger = require("logger")
    local ptutil = require("ptutil")
    local BD = require("ui/bidi")
    local BookInfoManager = require("bookinfomanager")

    -- ========================================================================
    -- Extract #subseries from EPUB OPF (calibre:user_metadata:#subseries)
    -- Returns nil, nil when not epub, OPF missing, or no subseries in OPF.
    -- ========================================================================
    local function extractSubseriesFromEpub(filepath)
        local filemanagerutil = require("apps/filemanager/filemanagerutil")
        local _, filetype = filemanagerutil.splitFileNameType(filepath)
        if filetype ~= "epub" then
            return nil, nil
        end

        -- Find the OPF file
        local opf_file
        local locate_opf_command = "unzip -lqq " .. escapeShellArg(filepath) .. " \"*.opf\" 2>/dev/null"
        local opf_match_pattern = "(%S+%.opf)$"

        local std_out = io.popen(locate_opf_command, "r")
        if std_out then
            for opf_line in std_out:lines() do
                opf_file = string.match(opf_line, opf_match_pattern)
                if opf_file then break end
            end
            std_out:close()
        end

        if not opf_file then
            return nil, nil
        end

        -- Extract and parse the OPF file
        local expand_opf_command = "unzip -p " .. escapeShellArg(filepath) .. " " .. escapeShellArg(opf_file) .. " 2>/dev/null"
        local subseries_name, subseries_index

        std_out = io.popen(expand_opf_command, "r")
        if std_out then
            for opf_line in std_out:lines() do
                -- Look for calibre:user_metadata:#subseries (content is HTML-entity-encoded JSON)
                if string.find(opf_line, "#subseries") and string.find(opf_line, "content=") then
                    -- Extract "#value#" (subseries name) and "#extra#" (index)
                    -- Try HTML-entity-encoded format first, then plain JSON
                    local val = string.match(opf_line, "&quot;#value#&quot;:%s*&quot;([^&]*)&quot;")
                    if not val then
                        val = string.match(opf_line, '"#value#"%s*:%s*"([^"]*)"')
                    end
                    if val and val ~= "" then
                        subseries_name = val
                    end

                    local idx = string.match(opf_line, "&quot;#extra#&quot;:%s*([%d%.]+)")
                    if not idx then
                        idx = string.match(opf_line, '"#extra#"%s*:%s*([%d%.]+)')
                    end
                    if idx then
                        subseries_index = tonumber(idx)
                    end

                    if subseries_name then
                        break
                    end
                end
            end
            std_out:close()
        end

        return subseries_name, subseries_index
    end

    -- ========================================================================
    -- Override BookInfoManager.getBookInfo to add subseries from EPUB when present
    -- ========================================================================
    local original_getBookInfo = BookInfoManager.getBookInfo
    function BookInfoManager:getBookInfo(filepath, get_cover)
        local bookinfo = original_getBookInfo(self, filepath, get_cover)
        if bookinfo then
            -- Extract subseries from EPUB if not already present
            if not bookinfo.subseries or not bookinfo.subseries_index then
                local subseries_name, subseries_index = extractSubseriesFromEpub(filepath)
                if subseries_name and subseries_name ~= "" then
                    bookinfo.subseries = subseries_name
                    bookinfo.subseries_index = subseries_index
                end
            end
            -- Store for formatSeries when called with 2 args (from listmenu/altbookstatuswidget)
            _G._pt_subseries_last_bookinfo = bookinfo
        end
        return bookinfo
    end

    -- ========================================================================
    -- Override formatSeries: same format for series and subseries, bullet only when subseries present
    -- ========================================================================
    local function applyFormat(fmt, name, index)
        if not name or name == "" then
            return ""
        end
        local s = fmt:gsub("{index}", index and tostring(index) or "")
        s = s:gsub("{series}", BD.auto(name))
        return s
    end

    function ptutil.formatSeries(series, series_index, subseries, subseries_index)
        -- When called with 2 args (from listmenu/altbookstatuswidget), use last bookinfo for subseries
        if subseries == nil and subseries_index == nil and _G._pt_subseries_last_bookinfo then
            local bi = _G._pt_subseries_last_bookinfo
            subseries = bi.subseries
            subseries_index = bi.subseries_index
        end

        -- Format series (suppress if index is 0)
        local formatted_series = ""
        if series and series ~= "" then
            if series_index and series_index ~= 0 then
                formatted_series = applyFormat(SERIES_FORMAT, series, series_index)
            else
                formatted_series = BD.auto(series)
            end
        end

        -- Format subseries (only if present and non-empty, and index is not 0)
        if subseries and subseries ~= "" and (subseries_index == nil or subseries_index ~= 0) then
            local formatted_sub = applyFormat(SERIES_FORMAT, subseries, subseries_index)
            if formatted_sub ~= "" then
                if formatted_series ~= "" then
                    formatted_series = formatted_series .. SERIES_SUBSERIES_SEP .. formatted_sub
                else
                    formatted_series = formatted_sub
                end
            end
        end

        return formatted_series
    end

    logger.info("PT Series-Subseries Format Patch: Applied.")
end

userpatch.registerPatchPluginFunc("projecttitle", patchCoverBrowser)
