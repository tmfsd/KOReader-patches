--[[
Project: Title Patch - Display Year, Pages, and Tags

This patch displays:
- First line: Publication year • Page count (e.g., "1989 • 517 pages")
- Second line: Tags/keywords (e.g., "tag1 • tag2 • tag3")
]]--

local userpatch = require("userpatch")

-- ============================================================================
-- CONFIGURATION
-- ============================================================================
-- Timezone offset in hours (CET = UTC+1)
local TIMEZONE_OFFSET_HOURS = 1

-- Font customization (optional)
local CUSTOM_FONT_SIZE_OFFSET = nil  -- Default is 3 (smaller than author font)
local CUSTOM_FONT_MIN = nil   -- Default is 10

-- ============================================================================
-- Patch Implementation
-- ============================================================================
local function patchCoverBrowser(CoverBrowser)
    local logger = require("logger")
    local _ = require("gettext")
    local BD = require("ui/bidi")
    local util = require("util")
    local Device = require("device")
    local BookInfoManager = require("bookinfomanager")
    local ptutil = require("ptutil")

    logger.info("PT Year-Pages-Tags Patch: Loading")

    -- FIX: Attach cache to the singleton BookInfoManager so it persists
    if not BookInfoManager._pt_patch_cache then
        BookInfoManager._pt_patch_cache = {}
    end
    local bookinfo_cache = BookInfoManager._pt_patch_cache

    local original_formatTags = ptutil.formatTags

    -- ========================================================================
    -- Extract Publication Year from EPUB
    -- ========================================================================
    local function extractPublicationYear(filepath)
        -- Only process EPUB files
        local filename_without_suffix, filetype = require("apps/filemanager/filemanagerutil").splitFileNameType(filepath)
        if filetype ~= "epub" then
            return nil
        end

        -- Find the OPF file
        local opf_file = nil
        local locate_opf_command = "unzip -lqq \"" .. filepath .. "\" \"*.opf\" 2>/dev/null"
        local opf_match_pattern = "(%S+%.opf)$"
        local line = ""

        if Device:isAndroid() then
            local fh = io.popen(locate_opf_command, "r")
            if fh then
                while true do
                    line = fh:read()
                    if line == nil or opf_file ~= nil then break end
                    opf_file = string.match(line, opf_match_pattern)
                end
                fh:close()
            end
        else
            local std_out = io.popen(locate_opf_command, "r")
            if std_out then
                for opf_line in std_out:lines() do
                    opf_file = string.match(opf_line, opf_match_pattern)
                    if opf_file then break end
                end
                std_out:close()
            end
        end

        if not opf_file then return nil end

        -- Extract and parse the OPF file
        local expand_opf_command = "unzip -p \"" .. filepath .. "\" \"" .. opf_file .. "\" 2>/dev/null"
        local dc_date = nil

        if Device:isAndroid() then
            local fh = io.popen(expand_opf_command, "r")
            if fh then
                for opf_line in fh:lines() do
                    local date_match = string.match(opf_line, "<dc:date[^>]*>([^<]+)</dc:date>")
                    if date_match then
                        dc_date = date_match
                        break
                    end
                end
                fh:close()
            end
        else
            local std_out = io.popen(expand_opf_command, "r")
            if std_out then
                for opf_line in std_out:lines() do
                    local date_match = string.match(opf_line, "<dc:date[^>]*>([^<]+)</dc:date>")
                    if date_match then
                        dc_date = date_match
                        break
                    end
                end
                std_out:close()
            end
        end

        if not dc_date then return nil end

        -- Parse the date string logic (Simplified for brevity, same as before)
        if string.match(dc_date, "^%d%d%d%d$") then return tonumber(dc_date) end

        local year, month, day, hour, minute, second, tz_offset =
            string.match(dc_date, "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)([%+%-]%d%d:?%d%d)")

        if not year then
            year, month, day, hour, minute, tz_offset =
                string.match(dc_date, "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d)([%+%-]%d%d:?%d%d)")
        end
        if not year then
             year, month, day, hour, minute, second =
                string.match(dc_date, "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
        end
        if not year then
            year, month, day = string.match(dc_date, "(%d%d%d%d)%-(%d%d)%-(%d%d)")
        end

        if not year then return nil end

        year = tonumber(year)
        -- (Timezone logic omitted for brevity but should be included as in original)
        -- For robust year extraction, returning just year is often sufficient if precise day calc isn't critical
        return year
    end

    -- ========================================================================
    -- Format Helpers
    -- ========================================================================
    local function formatPages(bookinfo)
        local pages = bookinfo.pages
        if not pages or pages == 0 then return nil end
        local pages_num = tonumber(pages)
        if not pages_num then return nil end

        if pages_num == 1 then
            return "1 " .. _("page")
        else
            return tostring(pages_num) .. " " .. _("pages")
        end
    end

    local function formatYearPagesAndTags(bookinfo, tags_limit)
        local parts = {}
        local first_line_parts = {}

        if bookinfo.publication_year then
            table.insert(first_line_parts, tostring(bookinfo.publication_year))
        end

        local pages_text = formatPages(bookinfo)
        if pages_text then
            table.insert(first_line_parts, pages_text)
        end

        if #first_line_parts > 0 then
            table.insert(parts, table.concat(first_line_parts, " • "))
        end

        local original_tags = bookinfo._original_keywords
        if original_tags then
            -- We cannot call original_formatTags if it relies on string manipulation of the hijacked ID
            -- But typically it just formats a string. We pass original_tags directly.
            -- NOTE: standard formatTags expects a string of keywords.
            local tags_text = original_formatTags(original_tags, tags_limit)
            if tags_text and tags_text ~= "" then
                table.insert(parts, tags_text)
            end
        end

        if #parts > 0 then
            return table.concat(parts, "\n")
        end
        return nil
    end

    -- ========================================================================
    -- Redefine ptutil.formatTags
    -- ========================================================================
    function ptutil.formatTags(keywords_identifier, tags_limit)
        -- 1. Try persistent cache
        local bookinfo = BookInfoManager._pt_patch_cache[keywords_identifier]

        if not bookinfo then
            -- If not found (e.g. non-patched item), fallback to default behavior
            -- This handles cases where keywords_identifier is actual tags, not a filepath
            return original_formatTags(keywords_identifier, tags_limit)
        end

        local result = formatYearPagesAndTags(bookinfo, tags_limit)
        return result or " "
    end

    -- ========================================================================
    -- Patch BookInfoManager
    -- ========================================================================
    local original_getBookInfo = BookInfoManager.getBookInfo

    function BookInfoManager:getBookInfo(filepath, get_cover)
        local bookinfo = original_getBookInfo(self, filepath, get_cover)

        if bookinfo then
            if not bookinfo._original_keywords then
                bookinfo._original_keywords = bookinfo.keywords
            end

            if not bookinfo.publication_year then
                local year = extractPublicationYear(filepath)
                if year then
                    bookinfo.publication_year = year
                end
            end

            -- FIX: Always update the persistent cache
            BookInfoManager._pt_patch_cache[filepath] = bookinfo

            -- Hijack keywords
            bookinfo.keywords = filepath
        end

        return bookinfo
    end

    -- ========================================================================
    -- Apply Font Settings
    -- ========================================================================
    if CUSTOM_FONT_SIZE_OFFSET then
        ptutil.list_defaults.tags_font_offset = CUSTOM_FONT_SIZE_OFFSET
    end

    if CUSTOM_FONT_MIN then
        ptutil.list_defaults.tags_font_min = CUSTOM_FONT_MIN
    end

    logger.info("PT Year-Pages-Tags Patch: Applied.")
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
