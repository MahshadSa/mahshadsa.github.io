// Quarto 1.9 canonicalizes every H1 into the title block on website pages.
// The homepage uses a custom hero, so finalize its semantic heading after the
// renderer has finished while leaving the authored layout and styling intact.

const outputDirectory = Deno.env.get("QUARTO_PROJECT_OUTPUT_DIR") || "_site";
const homepagePath = `${outputDirectory.replace(/[\\/]$/, "")}/index.html`;

let html: string;
try {
  html = await Deno.readTextFile(homepagePath);
} catch (error) {
  // A targeted render of another page may run before a homepage exists.
  if (error instanceof Deno.errors.NotFound) {
    Deno.exit(0);
  }
  throw error;
}

// The explicit title gives llms.txt a meaningful homepage label, but the
// visible title is the identically worded name inside the custom hero.
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
