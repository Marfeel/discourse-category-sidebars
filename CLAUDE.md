# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A Marfeel fork of the `discourse-category-sidebars` Discourse **theme component** (not a plugin). It renders Discourse topics as sidebars on category topic lists and inside the global Discourse sidebar. `about.json` declares `"component": true`; `.discourse-compatibility` pins a minimum Discourse version.

Because it's a theme component, there is no standalone dev server — it must be installed in a Discourse instance to be exercised. Preview via [theme-creator.discourse.org](https://theme-creator.discourse.org/) or a local Discourse instance.

## Tooling

- **Package manager is pnpm 9.x** (`packageManager` in `package.json` forbids npm/yarn). Node >= 22.
- There are **no npm scripts**. Linters inherit configs from `@discourse/lint-configs` and must be invoked directly:
  - `pnpm exec eslint .` (JS/gjs)
  - `pnpm exec prettier --check .`
  - `pnpm exec stylelint "**/*.scss"`
  - `pnpm exec ember-template-lint .`
- CI runs the shared `discourse/.github/.github/workflows/discourse-theme.yml@v1` workflow (see `.github/workflows/discourse-theme.yml`), which handles lint + theme tests. Running `pnpm install` locally is enough to reproduce the lint commands.

## Architecture

### Settings drive everything
`settings.yml` is the source of truth for which topics render where. Four parallel settings feed different rendering paths:

- `setup` — `category-slug, postID|...` pairs. Consumed by `CategorySidebar` to show a topic as a sidebar when browsing the matching category (or subcategory if `inherit_parent_sidebar`). The special slug `all` targets `/latest`, `/new`, `/unread`, `/top`.
- `setup_fixed` — `section-name, postID|...` pairs. Consumed by `FixedSidebar` to always render a sidebar section by **section name** (not category). The section name must correspond to an existing `.sidebar-section-wrapper[data-section-name="…"]` in Discourse's global sidebar.
- `setupDetails` / `setup_by_category_id` — alternate lookup schemes documented in the settings descriptions.
- `icon_mappings` — `Section Name, icon-id[, sidebar-name]|...`. Scoped-then-global resolution (see `FixedSidebar#findIcon`).

### Rendering pipeline

1. The Ember component tree is mounted from `javascripts/discourse/connectors/above-main-container/category-sidebar.gjs`, which renders both `<FixedSidebar />` and `<CategorySidebar0 />` above Discourse's main container.
2. `components/category-sidebar.gjs` resolves the current route's category (from `router.currentRoute`), matches it against `parsedSetting`, fetches the topic via `ajax('/t/<postID>.json')`, and injects `post.cooked` with `{{htmlSafe}}`.
3. `components/fixed-sidebar.gjs` fetches all `setup_fixed` topics in parallel (`Promise.allSettled`) and renders each as a `<div class="custom-sidebar-section" data-sidebar-name="...">`. Crucially, **this component does not render in the sidebar directly** — it renders the markup under `#main-outlet`, then `setupContents` *clones* each `.custom-sidebar-section` into the real Discourse `.sidebar-section-wrapper[data-section-name="..."]` node.
4. `common/body_tag.html` contains a `MutationObserver` that re-clones `.custom-sidebar-section` from `#main-outlet` into sidebar wrappers whenever Discourse rerenders and drops them. This is the fallback that keeps custom sections alive across route changes. It also contains a mobile-collapsible fix gated on a Discourse 3.5.0+ TODO.
5. `api-initializers/mobile-sidebar.gjs` additionally renders `<CustomCategorySidebar />` into the `after-sidebar-sections` outlet on mobile.
6. `api-initializers/hide-empty-sections.js` adds `body.no-fixed-sections` when there is **no current user** (anonymous visitors skip fixed sections entirely). `FixedSidebar#hideFailedSections` adds the same class if any `setup_fixed` fetch fails.
7. `initializers/sidebar-active-link.js` uses `MutationObserver` + `api.onPageChange` to add `.active` to the sidebar link matching the current topic ID, and to open ancestor `<details>` elements. Runs separate observers for the main outlet and the mobile panel.

### Two important invariants

- **Anonymous users never fetch.** Both `CategorySidebar` and `FixedSidebar` early-return when `!this.currentUser`. Any new feature that fetches topic content must respect this — topics in protected categories would 403, and the `no-fixed-sections` body class is what keeps the UI clean for guests.
- **Section ordering is CSS-driven.** `common/common.scss` assigns a CSS `order` to every `[data-section-name]` it knows about. When adding a new `setup_fixed` section, add a matching `order` rule in `common.scss`, otherwise it will render in source order at the end.

### Injected HTML is trusted
`htmlSafe` on `post.cooked` means topic authors control the sidebar DOM. This is intentional (topic markdown → sidebar HTML), but any code that processes that DOM (e.g. `applyIconsToContainer`) must tolerate arbitrary user markup.

## Code style

- `.gjs` (Glimmer template tag) is the preferred component format — co-located template with the class.
- Follow global instruction in `/home/marc/CLAUDE.md`: self-explanatory code over comments; only comment the non-obvious "why" (see the Discourse 3.5.0 TODO in `body_tag.html` for the right pattern).
