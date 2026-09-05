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
