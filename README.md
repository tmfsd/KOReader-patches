## [🞂 2-pt-year-pages-tags.lua](2-pt-year-pages-tags.lua)

Based on https://github.com/nahuelpucciarelli/KOReader.patches/blob/main/2-modular-tags.lua

This patch hijacks the "Show calibre tags/keywords" field to display the year of publication, the number of pages and the tags of a book. The year is read from `dc:date` in the epub file's metadata. This corresponds with the field "Published" in Calibre. So if you entered a publication date into that field the year will be shown here.

#### Adjust timezone
Because Calibre creates UTC dates when you enter a year into the "Published" field the wrong date can be shown on your reader. For example: if you entered "1989" Calibre will create the UTC date 1989-01-01T00:00:00+00:00, but only if you live in Greenwich. If you live in the CET timezone instead it will adjust for the difference and store the date as 1988-12-31T23:00:00+00:00. So instead of 1989 the reader will show 1988.

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