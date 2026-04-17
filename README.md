# mahshadsa.github.io

Personal website, portfolio, and digital garden. Built with [Quarto](https://quarto.org).

## Structure

```
content/
├── index.qmd                 ← Landing page (positioning + proof points)
├── now.qmd                   ← /now page (current focus, updated monthly)
├── about/
│   ├── cv.qmd                ← Timeline CV + downloadable PDF
│   └── contact.qmd           ← Email, Scholar, GitHub, ORCID
├── projects/                 ← Applied work & tools
│   ├── lemann-calculator/
│   ├── clip-cxr/
│   ├── annotation-app/
│   └── mre-pipeline/
├── research/
│   ├── publications.qmd      ← Papers & preprints
│   ├── presentations.qmd     ← Conference talks & posters
│   └── peer-review.qmd       ← Review activity log
├── notes/                    ← Digital garden
│   ├── concepts/             ← Explainers (Lémann Index, Bayesian ordinal, etc.)
│   ├── papers/               ← Paper summaries
│   └── methods/              ← Working methodology notes
└── personal/
    ├── books/                ← Reading notes
    └── ideas/                ← Loose threads
```

## Local development

### Prerequisites

Install Quarto: https://quarto.org/docs/get-started/

### Preview locally

```bash
cd portfolio
quarto preview
```

This starts a live-reloading server at `http://localhost:4848`. Edit any `.qmd` file and the browser refreshes automatically.

### Build the site

```bash
quarto render
```

Output goes to `_site/`.

## Filling in placeholders

All placeholder content is marked with `{{< placeholder "..." >}}` shortcodes, which render as yellow highlighted boxes in the browser. To fill them in:

1. **Search across all files**: `grep -rn "placeholder" --include="*.qmd"` to find every placeholder
2. **Replace with your real content** — remove the entire `{{< placeholder "..." >}}` and write your text directly
3. **Preview** to confirm it looks right

## Deploying to GitHub Pages

### First-time setup

```bash
# Initialize git
git init
git add .
git commit -m "Initial site scaffold"

# Create the GitHub repo (using GitHub CLI, or do it on github.com)
gh repo create mahshadsa.github.io --public --source=. --remote=origin

# Push
git push -u origin main
```

### Configure GitHub Pages

1. Go to **github.com/MahshadSa/mahshadsa.github.io → Settings → Pages**
2. Under **Build and deployment**, set:
   - Source: **GitHub Actions**
3. Create the workflow file (already included at `.github/workflows/publish.yml`)
4. Push — the site deploys automatically

### Subsequent updates

```bash
git add .
git commit -m "Update: description of changes"
git push
```

GitHub Actions will build and deploy automatically.

## Adding new content

### New garden note

```bash
# Create the file
touch notes/concepts/my-new-topic.qmd
```

Use this frontmatter template:

```yaml
---
title: "Your Note Title"
description: "One-line summary"
date: 2026-04-10
categories: [topic1, topic2]
---
```

The note will automatically appear on the Notes listing page.

### New project

Create a folder under `projects/` with an `index.qmd`:

```bash
mkdir projects/my-new-project
touch projects/my-new-project/index.qmd
```

### New book note

Same pattern under `personal/books/`.

## Customization

- **Colors & fonts**: Edit `assets/css/custom.scss` (palette is in the `scss:defaults` section)
- **Navigation**: Edit `_quarto.yml` → `website.navbar`
- **Site metadata**: Edit `_quarto.yml` → `website.title`, `site-url`, etc.

## License

Content © Mahshad S. Code is MIT.
