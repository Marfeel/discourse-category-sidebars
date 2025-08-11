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
  @service site;

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
    const mappings = settings.icon_mappings || "";
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
    console.log("initialize running", {
      mobileView: this.site.mobileView,
      narrowDesktopView: this.site.narrowDesktopView
    });
    
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
      console.log("setupContents running", { 
        mobileView: this.site.mobileView, 
        narrowDesktopView: this.site.narrowDesktopView,
        contentsLength: this.contents.length 
      });
      
      this.contents.forEach(({ section }) => {
        console.log(`Processing section: ${section}`);
        
        const contentElement = document.querySelector(
          `.custom-sidebar-section[data-sidebar-name="${section}"]`
        );

        console.log(`Content element found for ${section}:`, !!contentElement);

        if (contentElement) {
          this.addIconsToContent(contentElement);

          // Different behavior for mobile vs desktop
          if (this.site.mobileView || this.site.narrowDesktopView) {
            // In mobile, content is already rendered, just ensure collapsible behavior
            console.log(`Mobile mode: applying collapsible behavior directly to content for ${section}`);
            this.ensureCollapsibleBehavior(contentElement, section);
            
            // Also try to find and fix the mobile sidebar structure
            this.fixMobileSidebarStructure(section);
          } else {
            // Desktop behavior: move content to sidebar structure
            const targetElement = document.querySelector(
              `.sidebar-section-wrapper[data-section-name="${section}"]`
            );

            console.log(`Desktop mode - Target element found for ${section}:`, !!targetElement);

            if (targetElement) {
              const existingContent = targetElement.querySelector(
                `.custom-sidebar-section[data-sidebar-name="${section}"]`
              );
              if (!existingContent) {
                targetElement.appendChild(contentElement.cloneNode(true));
              }

              // remove on Discourse 3.5.0
              this.ensureCollapsibleBehavior(targetElement, section);
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
  ensureCollapsibleBehavior(element, section) {
    // TODO: Remove when Discourse 3.5.0+
    // Temporal fix where sidebar sections are not collapsible on mobile
    // Fixed in: https://github.com/discourse/discourse/commit/0abc33c5a25a5ab3535c678e6c5e03412fdd8b8a (3.5.0-beta8)

    const isMobile = this.site.mobileView || this.site.narrowDesktopView;

    console.log(`ensureCollapsibleBehavior running for ${section}:`, {
      mobileView: this.site.mobileView, 
      narrowDesktopView: this.site.narrowDesktopView,
      isMobile,
      elementType: element?.classList?.toString() || 'unknown'
    });

    if (isMobile) {
      // In mobile, we're working directly with content elements (details elements)
      const detailsElements = element.querySelectorAll('details');
      
      console.log(`Found ${detailsElements.length} details elements for ${section}`);
      
      detailsElements.forEach((details, index) => {
        console.log(`Processing details element ${index} for ${section}`);
        
        // Make sure details elements are interactive
        if (details.onclick === null) {
          details.onclick = (e) => {
            // Let the native details/summary behavior work
            console.log(`Details element clicked for ${section}`);
          };
        }
        
        // Ensure proper accessibility
        const summary = details.querySelector('summary');
        if (summary && !summary.getAttribute('role')) {
          summary.setAttribute('role', 'button');
          summary.setAttribute('aria-expanded', details.hasAttribute('open') ? 'true' : 'false');
          
          // Update aria-expanded when details toggle
          details.addEventListener('toggle', () => {
            summary.setAttribute('aria-expanded', details.hasAttribute('open') ? 'true' : 'false');
          });
        }
      });
    } else {
      // Desktop behavior - working with sidebar wrapper elements
      const headerButton = element.querySelector(".sidebar-section-header button");

      if (headerButton) {
        if (!headerButton.hasAttribute("aria-expanded")) {
          headerButton.setAttribute("aria-expanded", "true");
        }

        if (!headerButton.onclick) {
          headerButton.onclick = (e) => {
            e.preventDefault();
            const isExpanded = headerButton.getAttribute("aria-expanded") === "true";
            headerButton.setAttribute("aria-expanded", !isExpanded);

            const customContent = element.querySelector(".custom-sidebar-section");
            if (customContent) {
              customContent.style.display = !isExpanded ? "none" : "";
            }
          };
        }
      } else {
        const header = element.querySelector(".sidebar-section-header");
        if (header && !header.onclick) {
          header.style.cursor = "pointer";
          header.onclick = (e) => {
            e.preventDefault();
            const customContent = element.querySelector(".custom-sidebar-section");
            if (customContent) {
              const isVisible = customContent.style.display !== "none";
              customContent.style.display = isVisible ? "none" : "";

              const button = header.querySelector("button");
              if (button) {
                button.setAttribute("aria-expanded", !isVisible);
              }
            }
          };
        }
      }
    }
  }

  @action
  fixMobileSidebarStructure(section) {
    console.log(`Investigating mobile sidebar structure for ${section}`);
    
    // Look for possible sidebar containers in mobile
    const possibleContainers = [
      '.hamburger-dropdown .sidebar-sections',
      '.hamburger-dropdown [class*="sidebar"]',
      '.sidebar-wrapper',
      '.hamburger-panel',
      '.off-screen-menu',
      '.mobile-nav'
    ];
    
    possibleContainers.forEach(selector => {
      const container = document.querySelector(selector);
      if (container) {
        console.log(`Found container ${selector}:`, container);
        
        // Look for section headers within this container
        const headers = container.querySelectorAll('[class*="section-header"], .sidebar-section-header, button[aria-expanded]');
        console.log(`Found ${headers.length} headers in ${selector}:`, headers);
        
        headers.forEach((header, index) => {
          console.log(`Header ${index}:`, {
            className: header.className,
            textContent: header.textContent,
            hasAriaExpanded: header.hasAttribute('aria-expanded'),
            isButton: header.tagName === 'BUTTON'
          });
          
          // If this header corresponds to our section, try to make it collapsible
          if (header.textContent.toLowerCase().includes(section.toLowerCase())) {
            console.log(`Found matching header for ${section}:`, header);
            this.makeHeaderCollapsible(header, section);
          }
        });
      }
    });
    
    // Also check if there are any buttons or headers that might be our section
    const allButtons = document.querySelectorAll('button, [role="button"]');
    console.log(`Found ${allButtons.length} total buttons/clickable elements`);
    
    allButtons.forEach((button, index) => {
      if (button.textContent && button.textContent.toLowerCase().includes(section.toLowerCase())) {
        console.log(`Found potential section button for ${section}:`, {
          index,
          textContent: button.textContent,
          className: button.className,
          hasAriaExpanded: button.hasAttribute('aria-expanded')
        });
      }
    });
  }

  @action
  makeHeaderCollapsible(header, section) {
    console.log(`Attempting to make header collapsible for ${section}`);
    
    // If it's already a button with aria-expanded, ensure it works
    if (header.hasAttribute('aria-expanded')) {
      console.log(`Header already has aria-expanded for ${section}`);
      
      if (!header.onclick && header.tagName === 'BUTTON') {
        header.onclick = (e) => {
          console.log(`Collapsible header clicked for ${section}`);
          const isExpanded = header.getAttribute('aria-expanded') === 'true';
          header.setAttribute('aria-expanded', (!isExpanded).toString());
          
          // Try to find and toggle associated content
          const parent = header.closest('[class*="section"], [class*="wrapper"]');
          if (parent) {
            const content = parent.querySelector('.custom-sidebar-section, [class*="content"]');
            if (content) {
              content.style.display = isExpanded ? 'none' : '';
            }
          }
        };
      }
    } else {
      // If it's not already collapsible, try to make it so
      console.log(`Trying to add collapsible behavior to header for ${section}`);
      header.setAttribute('role', 'button');
      header.setAttribute('aria-expanded', 'true');
      header.style.cursor = 'pointer';
      
      header.onclick = (e) => {
        e.preventDefault();
        console.log(`Made collapsible header clicked for ${section}`);
        const isExpanded = header.getAttribute('aria-expanded') === 'true';
        header.setAttribute('aria-expanded', (!isExpanded).toString());
        
        // Try to find and toggle associated content
        const parent = header.closest('[class*="section"], [class*="wrapper"]');
        if (parent) {
          const content = parent.querySelector('.custom-sidebar-section, [class*="content"]');
          if (content) {
            content.style.display = isExpanded ? 'none' : '';
          }
        }
      };
    }
  }
}
