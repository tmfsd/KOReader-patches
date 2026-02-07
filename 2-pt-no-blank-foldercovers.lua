--[[
Project: Title Patch - No Blank Folder Covers

This patch modifies the folder cover display behavior in the cover list view.
If a folder or its subfolders contain less than four books with covers, it will
display only the available covers without empty placeholders.

This patch only works with user patches and does not modify any Project: Title
plugin files directly.
]]--

local userpatch = require("userpatch")

local function patchCoverBrowser(plugin)
    local logger = require("logger")
    logger.info("PT No-Blank-FolderCovers Patch: Loading")

    local ptutil = require("ptutil")
    if not ptutil or not ptutil.getSubfolderCoverImages then
        logger.warn("PT No-Blank-FolderCovers: ptutil.getSubfolderCoverImages not found")
        return
    end

    local Blitbuffer = require("ffi/blitbuffer")
    local CenterContainer = require("ui/widget/container/centercontainer")
    local FrameContainer = require("ui/widget/container/framecontainer")
    local Geom = require("ui/geometry")
    local HorizontalGroup = require("ui/widget/horizontalgroup")
    local HorizontalSpan = require("ui/widget/horizontalspan")
    local OverlapGroup = require("ui/widget/overlapgroup")
    local Size = require("ui/size")
    local VerticalGroup = require("ui/widget/verticalgroup")
    local VerticalSpan = require("ui/widget/verticalspan")
    local BookInfoManager = require("bookinfomanager")
    local SQ3 = require("lua-ljsqlite3/init")
    local DataStorage = require("datastorage")
    local util = require("util")
    local ImageWidget = require("ui/widget/imagewidget")

    local db_path = DataStorage:getSettingsDir() .. "/PT_bookinfo_cache.sqlite3"
    local border_thin = Size.border.thin
    local border_total = border_thin * 2
    local padding_small = Size.padding.small

    local function build_grid_no_blanks(images)
        local count = #images
        if count == 0 then return nil end

        local layout = VerticalGroup:new {}
        local row1 = HorizontalGroup:new { images[1] }
        if count > 1 then
            row1 = HorizontalGroup:new {
                images[1],
                HorizontalSpan:new { width = padding_small },
                images[2],
            }
        end
        table.insert(layout, row1)

        if count > 2 then
            table.insert(layout, VerticalSpan:new { width = padding_small })
            local row2 = HorizontalGroup:new { images[3] }
            if count > 3 then
                row2 = HorizontalGroup:new {
                    images[3],
                    HorizontalSpan:new { width = padding_small },
                    images[4],
                }
            end
            table.insert(layout, row2)
        end

        return layout
    end

    local function build_diagonal_stack_no_blanks(images, max_w, max_h)
        if #images == 0 then return nil end

        local stack_items = {}
        local stack_width, stack_height = 0, 0
        local offset = max_w * 0.08
        local inset_left, inset_top = 0, 0

        for _, img in ipairs(images) do
            local frame = FrameContainer:new {
                margin = 0,
                bordersize = 0,
                padding = nil,
                padding_left = inset_left,
                padding_top = inset_top,
                img,
            }
            local size = frame:getSize()
            stack_width = math.max(stack_width, size.w)
            stack_height = math.max(stack_height, size.h)
            inset_left = inset_left + offset
            inset_top = inset_top + offset
            table.insert(stack_items, frame)
        end

        local stack = OverlapGroup:new {
            dimen = Geom:new { w = stack_width, h = stack_height },
        }
        table.move(stack_items, 1, #stack_items, #stack + 1, stack)
        return CenterContainer:new {
            dimen = Geom:new { w = max_w, h = max_h },
            stack,
        }
    end

    local function query_cover_paths(folder, include_subfolders)
        if not util.directoryExists(folder) then return nil end

        local ok, db_conn = pcall(SQ3.open, db_path)
        if not ok or not db_conn then return nil end
        db_conn:set_busy_timeout(5000)

        local safe_folder = folder:gsub("'", "''"):gsub(";", "_")
        local query = include_subfolders and
            string.format([[
                SELECT directory, filename FROM bookinfo
                WHERE directory LIKE '%s/%%' AND has_cover = 'Y'
                ORDER BY RANDOM() LIMIT 16;
                ]], safe_folder) or
            string.format([[
                SELECT directory, filename FROM bookinfo
                WHERE directory = '%s/' AND has_cover = 'Y'
                ORDER BY RANDOM() LIMIT 16;
                ]], safe_folder)

        local res = db_conn:exec(query)
        db_conn:close()
        return res
    end

    local function get_thumbnail_size(max_w, max_h, is_stacked)
        if is_stacked then
            return (max_w * 0.75) - border_total - Size.padding.default,
                   (max_h * 0.75) - border_total - Size.padding.default
        else
            return (max_w - border_total * 2 - Size.padding.small) / 2,
                   (max_h - border_total * 2 - Size.padding.small) / 2
        end
    end

    local function build_cover_images(db_res, max_w, max_h, is_stacked)
        local covers = {}
        if not db_res or not db_res[1] or not db_res[2] then return covers end

        local directories, filenames = db_res[1], db_res[2]
        local max_img_w, max_img_h = get_thumbnail_size(max_w, max_h, is_stacked)
        for i, filename in ipairs(filenames) do
            if #covers >= 4 then break end
            local fullpath = directories[i] .. filename
            if util.fileExists(fullpath) then
                local bookinfo = BookInfoManager:getBookInfo(fullpath, true)
                if bookinfo and bookinfo.cover_bb then
                    local _, _, scale_factor = BookInfoManager.getCachedCoverSize(
                        bookinfo.cover_w, bookinfo.cover_h, max_img_w, max_img_h)
                    table.insert(covers, FrameContainer:new {
                        width = math.floor((bookinfo.cover_w * scale_factor) + border_total),
                        height = math.floor((bookinfo.cover_h * scale_factor) + border_total),
                        margin = 0,
                        padding = 0,
                        radius = Size.radius.default,
                        bordersize = border_thin,
                        color = Blitbuffer.COLOR_GRAY_3,
                        background = Blitbuffer.COLOR_GRAY_3,
                        ImageWidget:new {
                            image = bookinfo.cover_bb,
                            scale_factor = scale_factor,
                        },
                    })
                end
            end
        end
        return covers
    end

    function ptutil.getSubfolderCoverImages(filepath, max_w, max_h)
        if not filepath or not max_w or not max_h then return nil end

        local is_stacked = BookInfoManager:getSetting("use_stacked_foldercovers")
        local images = build_cover_images(query_cover_paths(filepath, false), max_w, max_h, is_stacked)

        if #images < 4 then
            images = build_cover_images(query_cover_paths(filepath, true), max_w, max_h, is_stacked)
        end

        if #images == 0 then return nil end

        return is_stacked and build_diagonal_stack_no_blanks(images, max_w, max_h) or build_grid_no_blanks(images)
    end

    logger.info("PT No-Blank-FolderCovers Patch: Applied")
end

userpatch.registerPatchPluginFunc("coverbrowser", patchCoverBrowser)
