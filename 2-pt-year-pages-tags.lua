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

    -- Cache indexed by FILEPATH
    local bookinfo_cache = {}

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
                    if line == nil or opf_file ~= nil then
                        break
                    end
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

        if not opf_file then
            return nil
        end

        -- Extract and parse the OPF file
        local expand_opf_command = "unzip -p \"" .. filepath .. "\" \"" .. opf_file .. "\" 2>/dev/null"
        local dc_date = nil

        if Device:isAndroid() then
            local fh = io.popen(expand_opf_command, "r")
            if fh then
                for opf_line in fh:lines() do
                    -- Look for dc:date tag
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
                    -- Look for dc:date tag
                    local date_match = string.match(opf_line, "<dc:date[^>]*>([^<]+)</dc:date>")
                    if date_match then
                        dc_date = date_match
                        break
                    end
                end
                std_out:close()
            end
        end

        if not dc_date then
            return nil
        end

        -- Parse the date string (ISO 8601 format: YYYY-MM-DDTHH:MM:SS+00:00 or similar)
        -- Examples: "1988-12-31T23:00:00+00:00", "1989-01-01", "1989"

        -- If we only have a year (e.g., "1989")
        if string.match(dc_date, "^%d%d%d%d$") then
            return tonumber(dc_date)
        end

        -- Try to match the full ISO 8601 format: YYYY-MM-DDTHH:MM:SS+00:00
        local year, month, day, hour, minute, second, tz_offset =
            string.match(dc_date, "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)([%+%-]%d%d:?%d%d)")

        -- If that doesn't match, try without seconds
        if not year then
            year, month, day, hour, minute, tz_offset =
                string.match(dc_date, "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d)([%+%-]%d%d:?%d%d)")
        end

        -- If that doesn't match, try without timezone
        if not year then
            year, month, day, hour, minute, second =
                string.match(dc_date, "(%d%d%d%d)%-(%d%d)%-(%d%d)T(%d%d):(%d%d):(%d%d)")
        end

        -- If that doesn't match, try date only
        if not year then
            year, month, day = string.match(dc_date, "(%d%d%d%d)%-(%d%d)%-(%d%d)")
        end

        if not year then
            return nil
        end

        year = tonumber(year)
        month = tonumber(month) or 1
        day = tonumber(day) or 1
        hour = tonumber(hour) or 0
        minute = tonumber(minute) or 0
        second = tonumber(second) or 0

        -- Handle timezone offset
        -- If the date is in UTC and we need to convert to CET (UTC+1)
        -- For example: 1988-12-31T23:00:00+00:00 in UTC = 1989-01-01T00:00:00 in CET
        if tz_offset then
            -- Parse timezone offset (e.g., "+00:00", "-05:00", "+01:00")
            local tz_sign, tz_h = string.match(tz_offset, "([%+%-])(%d%d)")
            if tz_sign and tz_h then
                local tz_hours = tonumber(tz_h)
                if tz_sign == "-" then
                    tz_hours = -tz_hours
                end

                -- Convert to local time (CET = UTC+1)
                hour = hour + TIMEZONE_OFFSET_HOURS - tz_hours

                -- Check if we've crossed into the next day (and potentially next year)
                if hour >= 24 then
                    hour = hour - 24
                    day = day + 1
                    -- Get days in current month
                    local days_in_month = 31
                    if month == 2 then
                        days_in_month = 28
                    elseif month == 4 or month == 6 or month == 9 or month == 11 then
                        days_in_month = 30
                    end
                    -- Check if we've crossed into the next month/year
                    if day > days_in_month then
                        day = 1
                        month = month + 1
                        if month > 12 then
                            month = 1
                            year = year + 1
                        end
                    end
                elseif hour < 0 then
                    hour = hour + 24
                    day = day - 1
                    if day < 1 then
                        month = month - 1
                        if month < 1 then
                            month = 12
                            year = year - 1
                        end
                        -- Get days in previous month
                        local days_in_month = 31
                        if month == 2 then
                            days_in_month = 28
                        elseif month == 4 or month == 6 or month == 9 or month == 11 then
                            days_in_month = 30
                        end
                        day = days_in_month
                    end
                end
            end
        else
            -- No timezone specified, assume UTC and apply offset
            hour = hour + TIMEZONE_OFFSET_HOURS
            if hour >= 24 then
                hour = hour - 24
                day = day + 1
                -- Get days in current month
                local days_in_month = 31
                if month == 2 then
                    days_in_month = 28
                elseif month == 4 or month == 6 or month == 9 or month == 11 then
                    days_in_month = 30
                end
                -- Check if we've crossed into the next month/year
                if day > days_in_month then
                    day = 1
                    month = month + 1
                    if month > 12 then
                        month = 1
                        year = year + 1
                    end
                end
            end
        end

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

        -- First line: Year • Pages
        local first_line_parts = {}

        -- Add year if available
        if bookinfo.publication_year then
            table.insert(first_line_parts, tostring(bookinfo.publication_year))
        end

        -- Add pages if available
        local pages_text = formatPages(bookinfo)
        if pages_text then
            table.insert(first_line_parts, pages_text)
        end

        -- Join first line with " • "
        if #first_line_parts > 0 then
            table.insert(parts, table.concat(first_line_parts, " • "))
        end

        -- Second line: Tags
        local original_tags = bookinfo._original_keywords
        if original_tags then
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
        -- 'keywords_identifier' here is actually the filepath we injected in getBookInfo
        -- We use it to look up the real data in our cache.

        local bookinfo = bookinfo_cache[keywords_identifier]

        -- Fallback: If cache miss (shouldn't happen), return nil
        if not bookinfo then
            return nil
        end

        local result = formatYearPagesAndTags(bookinfo, tags_limit)

        -- If our chosen metadata is empty, return space so line doesn't collapse
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

            -- Extract publication year from EPUB
            if not bookinfo.publication_year then
                local year = extractPublicationYear(filepath)
                if year then
                    bookinfo.publication_year = year
                end
            end

            -- This ensures 'keywords' is never nil, forcing KOReader to call formatTags.
            bookinfo.keywords = filepath
            bookinfo_cache[filepath] = bookinfo
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

