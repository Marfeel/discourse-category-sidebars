import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";
import { iconHTML } from "discourse-common/lib/icon-library";

export default class FixedSidebar extends Component {
  @service siteSettings;
  @service router;
  @service sidebarState;

  @tracked contents = [];
  @tracked loading = true;
  @tracked multilevelContent = null;
  @tracked currentCategoryConfig = null;

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

  get parsedMultilevelConfig() {
    console.log("parsedMultilevelConfig called");
    if (!settings.multilevel_config) {
      console.log("No multilevel_config setting found");
      return {};
    }
    
    console.log("multilevel_config raw:", settings.multilevel_config);
    
    const config = {};
    settings.multilevel_config.split("|").forEach((line) => {
      try {
        console.log("Parsing JSON:", line.trim());
        const categoryConfig = JSON.parse(line.trim());
        if (categoryConfig.id) {
          config[categoryConfig.id] = categoryConfig;
          console.log("Added config for category:", categoryConfig.id, categoryConfig);
        }
      } catch (error) {
        console.warn("Invalid multilevel config JSON:", line, error);
      }
    });
    
    console.log("Final parsed config:", config);
    return config;
  }

  getCurrentCategoryId() {
    const categorySlugPathWithID = this.router?.currentRoute?.params?.category_slug_path_with_id;
    if (categorySlugPathWithID) {
      const category = Category.findBySlugPathWithID(categorySlugPathWithID);
      if (category) {
        console.log("getCurrentCategoryId - category:", category.id);
        return category.id.toString();
      }
    }
    
    if (this.topicCategory) {
      console.log("getCurrentCategoryId - topicCategory:", this.topicCategory.id);
      return this.topicCategory.id.toString();
    }
    
    console.log("getCurrentCategoryId - no category found");
    return null;
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
      const results = await Promise.allSettled(
        this.fixedSettings.map(async (setting) => {
          const response = await ajax(`/t/${setting.postId}.json`);
          return {
            section: setting.section,
            content: response.post_stream.posts[0].cooked,
          };
        })
      );

      this.contents = results
        .filter((r) => r.status === "fulfilled")
        .map((r) => r.value);
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

  generateMultilevelContent(categoryConfig, currentCategoryId) {
    if (!categoryConfig) {
      return null;
    }

    let html = '<div class="multilevel-sidebar">';
    
    if (categoryConfig.parent) {
      const parentConfig = this.parsedMultilevelConfig[categoryConfig.parent];
      
      html += `<h3 class="category-title with-back">`;
      if (parentConfig) {
        html += `<a href="/c/${parentConfig.name.toLowerCase().replace(/\\s+/g, '-')}/${categoryConfig.parent}" class="back-link-inline">
          ${iconHTML("arrow-left")}
        </a>`;
      }
      html += `${categoryConfig.name}</h3>`;
      
      if (categoryConfig.items && categoryConfig.items.length > 0) {
        html += '<div class="category-items"><ul>';
        categoryConfig.items.forEach(item => {
          html += `<li class="category-item">
            <a href="${item.url}" class="item-link">${item.title}</a>
          </li>`;
        });
        html += '</ul></div>';
      }
    } else {
      if (categoryConfig.children && categoryConfig.children.length > 0) {
        html += '<div class="subcategories"><ul>';
        categoryConfig.children.forEach(childId => {
          const childConfig = this.parsedMultilevelConfig[childId];
          if (childConfig) {
            html += `<li class="subcategory-item">
              <div class="subcategory-header">
                <a href="/c/${childConfig.name.toLowerCase().replace(/\\s+/g, '-')}/${childId}" class="subcategory-link">${childConfig.name}</a>
              </div>`;
            
            if (childConfig.items && childConfig.items.length > 0) {
              html += '<ul class="subcategory-items">';
              childConfig.items.forEach(item => {
                html += `<li class="subcategory-item-link">
                  <a href="${item.url}" class="item-link">${item.title}</a>
                </li>`;
              });
              html += '</ul>';
            }
            html += '</li>';
          }
        });
        html += '</ul></div>';
      }
    }

    html += '</div>';
    return html;
  }

  hideOtherSections(keepSectionName) {
    console.log(" hiding other sections, keeping:", keepSectionName);
    const allSections = document.querySelectorAll('.sidebar-section-wrapper[data-section-name]');
    allSections.forEach(section => {
      const sectionName = section.getAttribute('data-section-name');
      if (sectionName !== keepSectionName) {
        section.style.display = 'none';
        section.classList.add('multilevel-hidden');
      }
    });
  }

  showAllSections() {
    console.log(" showing all sections");
    const hiddenSections = document.querySelectorAll('.sidebar-section-wrapper.multilevel-hidden');
    hiddenSections.forEach(section => {
      section.style.display = '';
      section.classList.remove('multilevel-hidden');
    });
    
    const hiddenHeaders = document.querySelectorAll('.sidebar-section-header.multilevel-header-hidden');
    hiddenHeaders.forEach(header => {
      header.style.display = '';
      header.classList.remove('multilevel-header-hidden');
    });
  }

  handleSectionHeader(targetElement, categoryConfig) {
    const sectionHeader = targetElement.querySelector('.sidebar-section-header');
    if (sectionHeader) {
      if (categoryConfig.parent) {
        // subcategory, hide the original header completely
        sectionHeader.style.display = 'none';
        sectionHeader.classList.add('multilevel-header-hidden');
        console.log("hiding header for subcategory");
      } else {
        // parent category, keep header visible but mark it
        sectionHeader.style.display = '';
        sectionHeader.classList.remove('multilevel-header-hidden');
        console.log("keeping header for parent category");
      }
    }
  }

  findTargetSection(categoryId) {
    const categoryConfig = this.parsedMultilevelConfig[categoryId];
    if (!categoryConfig) {
      return null;
    }
    
    if (categoryConfig.name.toLowerCase().includes('product')) {
      return 'product-guides';
    }
    
    if (categoryConfig.name.toLowerCase().includes('implementation')) {
      return 'implementation-guides';
    }
    
    if (categoryConfig.parent) {
      const parentConfig = this.parsedMultilevelConfig[categoryConfig.parent];
      if (parentConfig) {
        if (parentConfig.name.toLowerCase().includes('product')) {
          return 'product-guides';
        }
        if (parentConfig.name.toLowerCase().includes('implementation')) {
          return 'implementation-guides';
        }
      }
    }
    
    return 'product-guides';
  }

  @action
  setupContents() {
    schedule("afterRender", () => {
      const currentCategoryId = this.getCurrentCategoryId();
      const multilevelConfig = this.parsedMultilevelConfig;
      const categoryConfig = currentCategoryId ? multilevelConfig[currentCategoryId] : null;
      
      console.log("setupContents:");
      console.log("- currentCategoryId:", currentCategoryId);
      console.log("- categoryConfig:", categoryConfig);
      
      if (categoryConfig) {
        this.currentCategoryConfig = categoryConfig;
        this.multilevelContent = this.generateMultilevelContent(categoryConfig, currentCategoryId);
        
        // Find which section this category belongs to (product-guides or implementation-guides)
        const targetSectionName = this.findTargetSection(currentCategoryId);
        console.log("targetSectionName:", targetSectionName);
        
        if (targetSectionName) {
          this.hideOtherSections(targetSectionName);
          
          const targetElement = document.querySelector(
            `.sidebar-section-wrapper[data-section-name="${targetSectionName}"]`
          );
          
          if (targetElement) {
            this.handleSectionHeader(targetElement, categoryConfig);
            
            const existingContent = targetElement.querySelector('.custom-sidebar-section');
            if (existingContent) {
              existingContent.remove();
            }
            
            const multilevelElement = document.createElement('div');
            multilevelElement.className = 'custom-sidebar-section multilevel-section';
            multilevelElement.setAttribute('data-sidebar-name', targetSectionName);
            multilevelElement.innerHTML = this.multilevelContent;
            
            targetElement.appendChild(multilevelElement);
            
            console.log("Multilevel content inserted into:", targetSectionName);
          }
        }
        
        return;
      } else {
        this.showAllSections();
      }
      
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
