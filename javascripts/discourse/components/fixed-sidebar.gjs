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
  @tracked isInitialized = false;
  intersectionObserver = null;

  constructor() {
    super(...arguments);
    this.preHideSections();
    this.initialize();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.router.off("routeDidChange", this, this.toggleCurrentSection);
    this.cleanup();
  }

  cleanup() {
    // Clean up any remaining preload styles
    const preloadStyle = document.getElementById("fixed-sidebar-preload");
    if (preloadStyle) {
      preloadStyle.remove();
    }

    // Clean up intersection observer
    if (this.intersectionObserver) {
      this.intersectionObserver.disconnect();
      this.intersectionObserver = null;
    }
  }

  async initialize() {
    try {
      await this.fetchContents();
      this.setupContents();
      this.router.on("routeDidChange", this, this.toggleCurrentSection);
      this.toggleCurrentSection();
      this.isInitialized = true;
      this.showSections();
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error initializing fixed sidebar:", error);
      this.showSections(); // Show sections even if there's an error
    }
  }

  <template>
    {{#if this.isInitialized}}
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
    {{/if}}
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
  preHideSections() {
    // Pre-hide sections that will be replaced to prevent flash
    const sectionNames = this.fixedSettings.map((s) => s.section);
    if (sectionNames.length === 0) {
      return;
    }

    const style = document.createElement("style");
    style.id = "fixed-sidebar-preload";

    // Only target sections that will actually be modified
    const selectors = sectionNames
      .map((name) => `.sidebar-section-wrapper[data-section-name="${name}"]`)
      .join(", ");

    style.textContent = `
      ${selectors} {
        opacity: 0 !important;
        transition: opacity 0.15s ease !important;
      }
      ${selectors}.sidebar-ready {
        opacity: 1 !important;
      }
    `;
    document.head.appendChild(style);
  }

  @action
  showSections() {
    // Remove the preload styles and show sections
    schedule("afterRender", () => {
      const preloadStyle = document.getElementById("fixed-sidebar-preload");
      if (preloadStyle) {
        preloadStyle.remove();
      }

      // Mark all sections as ready
      document
        .querySelectorAll(".sidebar-section-wrapper[data-section-name]")
        .forEach((el) => {
          el.classList.add("sidebar-ready");
        });
    });
  }

  @action
  async fetchContents() {
    this.loading = true;
    try {
      // Use Promise.allSettled for better performance (parallel requests)
      const promises = this.fixedSettings.map(async (setting) => {
        try {
          const response = await ajax(`/t/${setting.postId}.json`);
          return {
            section: setting.section,
            content: response.post_stream.posts[0].cooked,
          };
        } catch (error) {
          // eslint-disable-next-line no-console
          console.error(
            `Error fetching content for section ${setting.section}, skipping:`,
            error
          );
          return null;
        }
      });

      const results = await Promise.allSettled(promises);
      this.contents = results
        .filter(
          (result) => result.status === "fulfilled" && result.value !== null
        )
        .map((result) => result.value);
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
    if (!this.contents.length) {
      return;
    }

    // Use Intersection Observer for better performance
    if (!this.intersectionObserver) {
      this.intersectionObserver = new IntersectionObserver(
        (entries) => {
          entries.forEach((entry) => {
            if (entry.isIntersecting) {
              this.applyContentToSection(entry.target);
            }
          });
        },
        {
          rootMargin: "50px",
          threshold: 0.1,
        }
      );
    }

    // Observe all target sections
    this.contents.forEach(({ section }) => {
      const targetElement = document.querySelector(
        `.sidebar-section-wrapper[data-section-name="${section}"]`
      );
      if (targetElement) {
        this.intersectionObserver.observe(targetElement);
        // Apply immediately for visible sections
        this.applyContentToSection(targetElement);
      }
    });
  }

  applyContentToSection(targetElement) {
    const sectionName = targetElement.getAttribute("data-section-name");
    const contentElement = document.querySelector(
      `.custom-sidebar-section[data-sidebar-name="${sectionName}"]`
    );
    const existingContent = targetElement.querySelector(
      `.custom-sidebar-section[data-sidebar-name="${sectionName}"]`
    );

    if (contentElement && !existingContent) {
      // Use requestAnimationFrame for smoother DOM updates
      requestAnimationFrame(() => {
        targetElement.appendChild(contentElement.cloneNode(true));
        targetElement.classList.add("sidebar-ready");

        document.dispatchEvent(new CustomEvent("sidebar:update-icons"));
      });
    } else if (!contentElement) {
      targetElement.classList.add("sidebar-ready");
    }
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
}
