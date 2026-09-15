local function metadata_text(meta, key)
  local value = meta[key]
  if value == nil then
    return nil
  end

  local result = pandoc.utils.stringify(value)
  if result == "" then
    return nil
  end
  return result
end

local function normalise_path(path)
  return path:gsub("\\", "/"):gsub("/+$", "")
end

local function canonical_url(site_url)
  local output_file = normalise_path(quarto.doc.output_file)
  local output_directory = normalise_path(quarto.project.output_directory)
  local relative_output = output_file

  if output_file:sub(1, #output_directory):lower() == output_directory:lower() then
    relative_output = output_file:sub(#output_directory + 1):gsub("^/", "")
  end

  site_url = site_url:gsub("/+$", "")
  if relative_output == "index.html" then
    return site_url .. "/"
  end
  return site_url .. "/" .. relative_output
end

local function html_attribute_escape(value)
  return value:gsub("&", "&amp;"):gsub('"', "&quot;")
end

local function metadata_date(meta, key)
  local value = metadata_text(meta, key)
  if value == nil then
    return nil
  end
  return pandoc.utils.normalize_date(value) or value
end

function Meta(meta)
  if not quarto.doc.is_format("html") then
    return meta
  end

  local site_url = metadata_text(meta, "schema-site-url")
  if site_url == nil then
    quarto.log.warning("schema-site-url is missing; canonical and page schema were not generated")
    return meta
  end

  local url = canonical_url(site_url)
  quarto.doc.include_text(
    "in-header",
    '<link rel="canonical" href="' .. html_attribute_escape(url) .. '">'
  )

  local schema_type = metadata_text(meta, "schema-type")
  if schema_type == nil or schema_type == "none" then
    return meta
  end

  local title = metadata_text(meta, "title") or metadata_text(meta, "pagetitle")
  local description = metadata_text(meta, "description")
  local date_published = metadata_date(meta, "date")
  local date_modified = metadata_date(meta, "date-modified")
  local root_url = site_url:gsub("/+$", "")
  local person_id = root_url .. "/#person"
  local website_id = root_url .. "/#website"
  local entity = {
    ["@context"] = "https://schema.org",
    ["@type"] = schema_type,
    ["@id"] = url .. "#" .. schema_type:lower(),
    url = url,
    description = description,
    isPartOf = { ["@id"] = website_id },
  }

  if schema_type == "ProfilePage" then
    entity.name = title
    entity.mainEntity = { ["@id"] = person_id }
  elseif schema_type == "Article" then
    entity.headline = title
    entity.author = { ["@id"] = person_id }
    entity.mainEntityOfPage = url
    entity.datePublished = date_published
    entity.dateModified = date_modified
  else
    entity.name = title
    entity.author = { ["@id"] = person_id }
    entity.datePublished = date_published
    entity.dateModified = date_modified
  end

  quarto.doc.include_text(
    "in-header",
    '<script type="application/ld+json">' .. quarto.json.encode(entity) .. '</script>'
  )

  return meta
end

local function has_class(element, class_name)
  if element == nil or element.classes == nil then
    return false
  end
  for _, class in ipairs(element.classes) do
    if class == class_name then
      return true
    end
  end
  return false
end

local function first_inline_with_class(inlines, class_name)
  for _, inline in ipairs(inlines) do
    if has_class(inline, class_name) then
      return inline
    end
  end
  return nil
end

-- Quarto wraps consecutive inline spans in a paragraph. Convert shared row
-- headers to the block structure their CSS and document hierarchy require.
function Div(div)
  if has_class(div, "worklist-label") and #div.content == 1 and div.content[1].t == "Para" then
    local inlines = div.content[1].content
    local label = inlines[1]
    local link = inlines[#inlines]
    if label and label.t == "Span" and link and link.t == "Span" then
      div.content = {
        pandoc.Header(2, label.content, pandoc.Attr("", { "worklist-section-title", "no-anchor" })),
        pandoc.Para({ link }),
      }
    end
  elseif has_class(div, "worklist-head") and #div.content == 1 and div.content[1].t == "Para" then
    local inlines = div.content[1].content
    local title = first_inline_with_class(inlines, "worklist-title")
    local date = first_inline_with_class(inlines, "worklist-date")
    if title and date then
      div.content = {
        pandoc.Header(3, { title }, pandoc.Attr("", { "worklist-entry-title", "no-anchor" })),
        pandoc.Para({ date }),
      }
    end
  elseif has_class(div, "timeline-head") and #div.content == 1 and div.content[1].t == "Para" then
    local inlines = div.content[1].content
    local date = first_inline_with_class(inlines, "timeline-date")
    local title = first_inline_with_class(inlines, "timeline-title")
    if title and date then
      div.content = {
        pandoc.Para({ date }),
        pandoc.Header(2, title.content, pandoc.Attr("", { "timeline-title", "no-anchor" })),
      }
    end
  elseif has_class(div, "pub-entry") and #div.content > 0 and div.content[1].t == "Para" then
    local title = first_inline_with_class(div.content[1].content, "pub-title")
    if title then
      div.content[1] = pandoc.Header(3, title.content, pandoc.Attr("", { "pub-title", "no-anchor" }))
    end
  elseif has_class(div, "timeline-item") or has_class(div, "timeline-child") then
    local heading_level = has_class(div, "timeline-child") and 4 or 3
    local content = {}
    for _, block in ipairs(div.content) do
      if block.t == "Para" then
        local title = first_inline_with_class(block.content, "timeline-title")
        if title then
          for _, inline in ipairs(block.content) do
            if inline.t == "Span" then
              if has_class(inline, "timeline-title") then
                table.insert(content, pandoc.Header(
                  heading_level,
                  inline.content,
                  pandoc.Attr("", { "timeline-title", "no-anchor" })
                ))
              else
                table.insert(content, pandoc.Para({ inline }))
              end
            end
          end
        else
          table.insert(content, block)
        end
      else
        table.insert(content, block)
      end
    end
    div.content = content
  end

  return div
end

-- All authored Markdown tables receive the same keyboard-accessible scroll
-- region. This preserves table semantics while preventing page overflow.
function Table(table)
  return pandoc.Div(
    { table },
    pandoc.Attr("", { "table-scroll" }, {
      { "role", "region" },
      { "aria-label", "Scrollable table" },
      { "tabindex", "0" },
    })
  )
end
