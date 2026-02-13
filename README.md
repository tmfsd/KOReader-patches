## [🞂 2-pt-year-pages-tags.lua](2-pt-year-pages-tags.lua)

Based on [2-modular-tags.lua](https://github.com/nahuelpucciarelli/KOReader.patches/blob/main/2-modular-tags.lua)

This patch hijacks the "Show calibre tags/keywords" field to display the year of publication, the number of pages and the tags of a book. The year is read from `dc:date` in the epub file's metadata. This corresponds with the field "Published" in Calibre. If you entered a publication date into that field the year will be shown here.

<img width="1264" height="697" alt="image" src="https://github.com/user-attachments/assets/4acd0995-fea9-4518-9c90-da1affe37e5d" />

#### Adjust timezone
Because Calibre creates UTC dates when you enter a year into the "Published" field the wrong date can be shown on your reader. For example: if you entered "1989" but live in the CET timezone Calibre will create the UTC date 1988-12-31T23:00:00+00:00. So instead of 1989 the reader will show 1988.

Adjust the `TIMEZONE_OFFSET_HOURS` by the number of hours your timezone differs from UTC to prevent that.

#### Font Size
You can adjust how the text looks:

``` lua
-- Make text bigger (less offset from author font size)
local CUSTOM_FONT_SIZE_OFFSET = 1

-- Make text smaller (more offset from author font size)
local CUSTOM_FONT_SIZE_OFFSET = 5

-- Set minimum font size
local CUSTOM_FONT_MIN = 12
```

-----

## [🞂 2-pt-no-blank-foldercovers.lua](2-pt-no-blank-foldercovers.lua)

<img width="1264" height="840" alt="image" src="https://github.com/user-attachments/assets/a3e506d5-399a-496a-93d4-52c2f9793a20" />

This patch removes blank placeholders from the folder covers in Cover Grid view and Cover List view if a folder and it\'s subfolders hold less than four books.

-----

## [🞂 2-pt-modify-series-subseries-format.lua](2-pt-modify-series-subseries-format.lua)

Based on [2-pt-modify-series-format.lua](https://github.com/loeffner/KOReader.patches/blob/main/project-title/2-pt-modify-series-format.lua)

<img width="1264" height="401" alt="image" src="https://github.com/user-attachments/assets/ad80cb43-114b-4aa0-b444-8bb9557b0cab" />

Customize the format of the series in listview. Also displays the subseries if available.

-----

## [🞂 2-pt-hide-author.lua](2-pt-hide-author.lua)

Hides the author(s) if a series/subseries is displayed.
