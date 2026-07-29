--[[
    User patch for Project: Title. Hide author names when series is displayed.
    License: GNU AGPL v3
--]]

local userpatch = require("userpatch")

local function patchCoverBrowser(plugin)
    local ptutil = require("ptutil")

    function ptutil.formatAuthorSeries(authors, series, series_mode, show_tags)
        local formatted_author_series = ""

        -- If series is present and should be shown, hide authors and show only series
        if series_mode == "series_in_separate_line" and series and series ~= "" then
            formatted_author_series = series
        elseif authors and authors ~= "" then
            -- No series, show authors normally
            formatted_author_series = authors
        end

        return formatted_author_series
    end
end

userpatch.registerPatchPluginFunc("projecttitle", patchCoverBrowser)
