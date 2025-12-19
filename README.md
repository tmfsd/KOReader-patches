## [🞂 2-pt-year-pages-tags.lua](2-pt-year-pages-tags.lua)

Based on [2-modular-tags.lua](https://github.com/nahuelpucciarelli/KOReader.patches/blob/main/2-modular-tags.lua)

This patch hijacks the "Show calibre tags/keywords" field to display the year of publication, the number of pages and the tags of a book. The year is read from `dc:date` in the epub file's metadata. This corresponds with the field "Published" in Calibre. If you entered a publication date into that field the year will be shown here.

<img width="1264" height="697" alt="image" src="https://github.com/user-attachments/assets/4acd0995-fea9-4518-9c90-da1affe37e5d" />

#### Adjust timezone
Because Calibre creates UTC dates when you enter a year into the "Published" field the wrong date can be shown on your reader. For example: if you entered "1989" but live in the CET timezone Calibre will create the UTC date 1988-12-31T23:00:00+00:00. So instead of 1989 the reader will show 1988.

Adjust the `TIMEZONE_OFFSET_HOURS` by the number of hours your timezone differs from UTC to prevent that.

#### Font Size
You can adjust how the text looks:

```lua
-- Make text bigger (less offset from author font size)
local CUSTOM_FONT_SIZE_OFFSET = 1

-- Make text smaller (more offset from author font size)
local CUSTOM_FONT_SIZE_OFFSET = 5

-- Set minimum font size
local CUSTOM_FONT_MIN = 12
