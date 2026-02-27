import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";

export default class FixedSidebar extends Component {
  @service siteSettings;
  @service router;
  @service sidebarState;

  @tracked contents = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.initialize();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.iconObserver?.disconnect();
    this.router.off("routeDidChange", this, this.toggleCurrentSection);
  }

  get iconMappings() {
    const mappings = settings.icon_mappings || "";

    return mappings
      .split("|")
      .map((mapping) => {
        if (!mapping || !mapping.includes(",")) {
          return null;
        }
        const parts = mapping.split(",").map((s) => s.trim());
        const [sectionName, iconId, sidebarName] = parts;
        if (!sectionName || !iconId) {
          return null;
        }
        return { sectionName, iconId, sidebarName: sidebarName || null };
      })
      .filter(Boolean);
  }

  findIcon(sectionName, sidebarName) {
    const scoped = this.iconMappings.find(
      (m) => m.sectionName === sectionName && m.sidebarName === sidebarName
    );
    if (scoped) {
      return scoped.iconId;
    }

    const global = this.iconMappings.find(
      (m) => m.sectionName === sectionName && !m.sidebarName
    );
    return global?.iconId ?? null;
  }

  async initialize() {
    await this.fetchContents();
    await this.setupContents();
    this.initIconObserver();
    this.router.on("routeDidChange", this, this.toggleCurrentSection);
    this.toggleCurrentSection();
  }

  <template>
    {{#each this.contents as |content|}}
      <div
        class="custom-sidebar-section"
        data-sidebar-name={{content.section}}
        {{didUpdate this.setupContents this.router.currentRoute}}
      >
        {{#unless this.loading}}
          {{htmlSafe content.content}}
        {{/unless}}
      </div>
    {{/each}}
  </template>

  get fixedSettings() {
    const setupFixed = (settings.setup_fixed || "")
      .split("|")
      .map((entry) => {
        if (!entry || !entry.includes(",")) {
          return null;
        }
        const [section, postId] = entry.split(",");
        return section && postId
          ? { section: section.trim(), postId: postId.trim() }
          : null;
      })
      .filter(Boolean);

    return setupFixed;
  }

  get categoryIdTopic() {
    return this.router?.currentRoute?.parent?.attributes?.category_id;
  }

  get topicCategory() {
    return this.categoryIdTopic
      ? Category.findById(this.categoryIdTopic)
      : null;
  }

  @action
  async fetchContents() {
    this.loading = true;
    try {
      const successfulContents = [];

      for (const setting of this.fixedSettings) {
        try {
          const response = await ajax(`/t/${setting.postId}.json`);
          successfulContents.push({
            section: setting.section,
            content: response.post_stream.posts[0].cooked,
          });
        } catch (error) {
          // eslint-disable-next-line no-console
          console.error(
            `Error fetching content for section ${setting.section}, skipping:`,
            error
          );
        }
      }

      this.contents = successfulContents;
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(
        "Error fetching fixed content for multiple sidebars:",
        error
      );
      this.contents = [];
    } finally {
      this.loading = false;
    }
  }

  @action
  setupContents() {
    schedule("afterRender", () => {
      this.contents.forEach(({ section }) => {
        const contentElement = document.querySelector(
          `.custom-sidebar-section[data-sidebar-name="${section}"]`
        );

        if (contentElement) {
          const targetElement = document.querySelector(
            `.sidebar-section-wrapper[data-section-name="${section}"]`
          );
          if (targetElement) {
            const existingContent = targetElement.querySelector(
              `.custom-sidebar-section[data-sidebar-name="${section}"]`
            );
            if (!existingContent) {
              targetElement.appendChild(contentElement.cloneNode(true));
            }
          }
        }
      });
    });
  }

  @action
  toggleCurrentSection() {
    schedule("afterRender", () => {
      const parentTopicCategorySlug = Category.findById(
        this.topicCategory?.parent_category_id
      )?.slug;
      const currentSection = this.contents.find((content) => {
        if (parentTopicCategorySlug === "configuration") {
          return content.section === "implementation-guides";
        }

        return content.section === parentTopicCategorySlug;
      });

      if (currentSection) {
        this.sidebarState.expandSection(currentSection.section);
      }
    });
  }

  createIconSvg(iconId) {
    const symbolEl = document.querySelector(`symbol#${iconId}`);
    if (!symbolEl) {
      return null;
    }

    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.classList.add(
      "fa",
      "d-icon",
      "svg-icon",
      "prefix-icon",
      "svg-string",
      `d-icon-${iconId}`
    );
    svg.setAttribute("viewBox", "0 0 512 512");
    Array.from(symbolEl.childNodes).forEach((child) =>
      svg.appendChild(child.cloneNode(true))
    );
    return svg;
  }

  applyIconsToContainer(container) {
    const sidebarName = container.dataset?.sidebarName ?? null;

    // Type 1: <details> > <summary>
    container.querySelectorAll("details").forEach((detail) => {
      const summary = detail.querySelector("summary");
      if (!summary) {
        return;
      }
      const sectionName = summary.textContent.trim();
      const iconId = this.findIcon(sectionName, sidebarName);

      if (iconId && !detail.querySelector(`.d-icon-${iconId}`)) {
        const svg = this.createIconSvg(iconId);
        if (svg) {
          detail.classList.add(`mrf-sidebar-${iconId}`);
          summary.prepend(svg);
        }
      }
    });

    // Type 2: ul > li > a > i
    container.querySelectorAll("ul > li > a > i").forEach((iElement) => {
      const anchor = iElement.closest("a");
      if (!anchor || anchor.querySelector(".d-icon")) {
        return;
      }
      const linkText = Array.from(anchor.childNodes)
        .filter((node) => node.nodeType === Node.TEXT_NODE)
        .map((node) => node.textContent.trim())
        .join("")
        .trim();

      const iconId = this.findIcon(linkText, sidebarName);
      if (iconId) {
        const svg = this.createIconSvg(iconId);
        if (svg) {
          iElement.replaceWith(svg);
        }
      }
    });
  }

  initIconObserver() {
    this.iconObserver?.disconnect();

    this.iconObserver = new MutationObserver(() => {
      const sections = document.querySelectorAll(
        ".custom-sidebar-section[data-sidebar-name]"
      );
      if (!sections.length) {
        return;
      }

      this.iconObserver.disconnect();
      sections.forEach((section) => this.applyIconsToContainer(section));

      if (document.body) {
        this.iconObserver.observe(document.body, {
          childList: true,
          subtree: true,
        });
      }
    });

    if (document.body) {
      this.iconObserver.observe(document.body, {
        childList: true,
        subtree: true,
      });
    }

    // Initial pass
    document
      .querySelectorAll(".custom-sidebar-section[data-sidebar-name]")
      .forEach((section) => this.applyIconsToContainer(section));
  }
}
