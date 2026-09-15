// Finalize output that Quarto cannot express directly in project metadata.

const outputDirectory = Deno.env.get("QUARTO_PROJECT_OUTPUT_DIR") || "_site";
const normalizedOutputDirectory = outputDirectory.replace(/[\\/]$/, "");

async function finalizeHomepageHeading() {
  const homepagePath = `${normalizedOutputDirectory}/index.html`;

  let html: string;
  try {
    html = await Deno.readTextFile(homepagePath);
  } catch (error) {
    // A targeted render of another page may run before a homepage exists.
    if (error instanceof Deno.errors.NotFound) {
      return;
    }
    throw error;
  }

  // Quarto 1.9 canonicalizes every H1 into the title block on website pages.
  // The homepage uses the identically worded name inside its custom hero.
  html = html.replace(
    /<header id="title-block-header"[^>]*>[\s\S]*?<\/header>\s*/,
    "",
  );

  const heroPattern = /<p><span class="hero-name" data-semantic-h1="true">([\s\S]*?)<\/span><\/p>/g;
  const heroMatches = [...html.matchAll(heroPattern)];

  if (heroMatches.length === 1) {
    html = html.replace(heroPattern, '<h1 class="hero-name">$1</h1>');
  } else if (!/<h1 class="hero-name">/.test(html)) {
    throw new Error(
      `Expected one homepage hero name to convert, found ${heroMatches.length}.`,
    );
  }

  const h1Count = (html.match(/<h1\b/g) || []).length;
  if (h1Count !== 1) {
    throw new Error(`Expected exactly one homepage H1, found ${h1Count}.`);
  }

  await Deno.writeTextFile(homepagePath, html);
}

function yamlScalar(
  document: string,
  key: string,
  requireFrontMatter = true,
): string | undefined {
  const frontMatter = document.match(/^---\s*\r?\n([\s\S]*?)\r?\n---(?:\r?\n|$)/);
  if (!frontMatter && requireFrontMatter) {
    return undefined;
  }
  const yaml = frontMatter ? frontMatter[1] : document;

  const escapedKey = key.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  const match = yaml.match(
    new RegExp(`^${escapedKey}:[ \\t]*(.*?)[ \\t]*$`, "m"),
  );
  if (!match) {
    return undefined;
  }

  let value = match[1].replace(/[ \t]+#.*$/, "").trim();
  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    value = value.slice(1, -1);
  }
  return value || undefined;
}

function normalizedW3cDate(value: string, sourcePath: string): string {
  if (/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    const parsed = new Date(`${value}T00:00:00Z`);
    if (!Number.isNaN(parsed.valueOf()) && parsed.toISOString().slice(0, 10) === value) {
      return value;
    }
  }

  if (
    /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2}(?:\.\d+)?)?(?:Z|[+-]\d{2}:\d{2})$/.test(
      value,
    )
  ) {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.valueOf())) {
      return parsed.toISOString();
    }
  }

  throw new Error(
    `${sourcePath} has a sitemap date that is not a valid W3C date or date-time: ${value}`,
  );
}

function sourcePathForOutput(relativeOutput: string): string {
  if (relativeOutput === "index.html") {
    return "index.qmd";
  }
  if (!relativeOutput.endsWith(".html")) {
    throw new Error(`Cannot map sitemap output to a QMD source: ${relativeOutput}`);
  }
  return relativeOutput.slice(0, -5) + ".qmd";
}

function canonicalLocation(siteUrl: string, relativeOutput: string): string {
  const root = siteUrl.replace(/\/+$/, "");

  // URL policy: the site root is canonicalized to `/`; every non-root page
  // retains Quarto's existing .html output path, including nested index.html.
  return relativeOutput === "index.html"
    ? `${root}/`
    : `${root}/${relativeOutput.replace(/\\/g, "/")}`;
}

async function normalizeSitemap() {
  const sitemapPath = `${normalizedOutputDirectory}/sitemap.xml`;
  let sitemap: string;
  try {
    sitemap = await Deno.readTextFile(sitemapPath);
  } catch (error) {
    if (error instanceof Deno.errors.NotFound) {
      return;
    }
    throw error;
  }

  const projectConfig = await Deno.readTextFile("_quarto.yml");
  const siteUrl = yamlScalar(projectConfig, "schema-site-url", false);
  if (!siteUrl) {
    throw new Error("schema-site-url is required to normalize the sitemap.");
  }

  const urlBlocks = [...sitemap.matchAll(/<url>[\s\S]*?<\/url>/g)];
  if (urlBlocks.length === 0) {
    throw new Error("The generated sitemap does not contain any URL entries.");
  }

  const normalizedBlocks = await Promise.all(
    urlBlocks.map(async ({ 0: block }) => {
      const locationMatch = block.match(/<loc>([^<]+)<\/loc>/);
      if (!locationMatch) {
        throw new Error("A sitemap URL entry is missing its <loc> element.");
      }

      const pathname = decodeURIComponent(new URL(locationMatch[1]).pathname);
      const relativeOutput = pathname === "/" || pathname === "/index.html"
        ? "index.html"
        : pathname.replace(/^\//, "");
      const sourcePath = sourcePathForOutput(relativeOutput);
      const source = await Deno.readTextFile(sourcePath);
      const explicitDate = yamlScalar(source, "date-modified") ??
        yamlScalar(source, "date");
      const lastModified = explicitDate
        ? normalizedW3cDate(explicitDate, sourcePath)
        : undefined;
      const location = canonicalLocation(siteUrl, relativeOutput);

      let normalized = block.replace(
        /\r?\n\s*<lastmod>[^<]*<\/lastmod>/,
        "",
      );
      normalized = normalized.replace(
        /<loc>[^<]+<\/loc>/,
        `<loc>${location}</loc>${
          lastModified ? `\n    <lastmod>${lastModified}</lastmod>` : ""
        }`,
      );
      return normalized;
    }),
  );

  let index = 0;
  const normalizedSitemap = sitemap.replace(
    /<url>[\s\S]*?<\/url>/g,
    () => normalizedBlocks[index++],
  );
  await Deno.writeTextFile(sitemapPath, normalizedSitemap);
}

await finalizeHomepageHeading();
await normalizeSitemap();
