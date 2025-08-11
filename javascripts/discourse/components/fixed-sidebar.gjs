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
    this.router.off("routeDidChange", this, this.toggleCurrentSection);
  }

  get iconSections() {
    const mappings = this.siteSettings.icon_mappings || "";
    const result = {};

    mappings.split("|").forEach((mapping) => {
      if (!mapping || !mapping.includes(",")) {
        return;
      }
      const [sectionName, iconId] = mapping.split(",").map((s) => s.trim());
      if (sectionName && iconId) {
        result[sectionName] = iconId;
      }
    });

    return result;
  }

  async initialize() {
    await this.fetchContents();
    await this.setupContents();
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
          // Add icons to the content first, before moving to sidebar
          this.addIconsToContent(contentElement);
          
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

  @action
  addIconsToContent(contentElement) {
    const sections = contentElement.querySelectorAll("details");

    sections.forEach((section) => {
      const sectionName = section.querySelector("summary")?.textContent.trim();
      const icon = this.iconSections[sectionName];

      if (icon && !section.querySelector(`.d-icon-${icon}`)) {
        section.classList.add(`mrf-sidebar-${icon}`);

        const svg = document.createElementNS(
          "http://www.w3.org/2000/svg",
          "svg"
        );
        svg.classList.add(
          "fa",
          "d-icon",
          "svg-icon",
          "prefix-icon",
          "svg-string",
          `d-icon-${icon}`
        );
        svg.setAttribute("viewBox", "0 0 512 512");

        const path = document.querySelector(`symbol#${icon}`);
        if (path) {
          svg.innerHTML = path.innerHTML;
          section.querySelector("summary").prepend(svg);
        }
      }
    });
  }

  @action
  addIconSections() {
    const customSidebarSections = document.querySelectorAll(
      ".sidebar-sections .custom-sidebar-section > details"
    );

    if (customSidebarSections) {
      customSidebarSections.forEach((section) => {
        const sectionName = section.querySelector("summary").textContent.trim();
        const icon = this.iconSections[sectionName];

        if (icon && !section.querySelector(`.d-icon-${icon}`)) {
          section.classList.add(`mrf-sidebar-${icon}`);

          const svg = document.createElementNS(
            "http://www.w3.org/2000/svg",
            "svg"
          );
          svg.classList.add(
            "fa",
            "d-icon",
            "svg-icon",
            "prefix-icon",
            "svg-string",
            `d-icon-${icon}`
          );
          svg.setAttribute("viewBox", "0 0 512 512");

          const path = document.querySelector(`symbol#${icon}`);
          if (path) {
            svg.innerHTML = path.innerHTML;

            section.querySelector("summary").prepend(svg);
          }
        }
      });
    }
  }
}
