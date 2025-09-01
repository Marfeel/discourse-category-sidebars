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

  get parsedMultilevelConfig() {
    console.log("FixedSidebar - parsedMultilevelConfig called");
    if (!settings.multilevel_config) {
      console.log("FixedSidebar - No multilevel_config setting found");
      return {};
    }
    
    console.log("FixedSidebar - multilevel_config raw:", settings.multilevel_config);
    
    const config = {};
    settings.multilevel_config.split("|").forEach((line) => {
      try {
        console.log("FixedSidebar - Parsing JSON line:", line.trim());
        const categoryConfig = JSON.parse(line.trim());
        if (categoryConfig.id) {
          config[categoryConfig.id] = categoryConfig;
          console.log("FixedSidebar - Added config for category:", categoryConfig.id, categoryConfig);
        }
      } catch (error) {
        console.warn("FixedSidebar - Invalid multilevel config JSON:", line, error);
      }
    });
    
    console.log("FixedSidebar - Final parsed config:", config);
    return config;
  }

  getCurrentCategoryId() {
    const categorySlugPathWithID = this.router?.currentRoute?.params?.category_slug_path_with_id;
    if (categorySlugPathWithID) {
      const category = Category.findBySlugPathWithID(categorySlugPathWithID);
      if (category) {
        console.log("FixedSidebar - getCurrentCategoryId - category:", category.id);
        return category.id.toString();
      }
    }
    
    if (this.topicCategory) {
      console.log("FixedSidebar - getCurrentCategoryId - topicCategory:", this.topicCategory.id);
      return this.topicCategory.id.toString();
    }
    
    console.log("FixedSidebar - getCurrentCategoryId - no category found");
    return null;
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

  generateMultilevelContent(categoryConfig, currentCategoryId) {
    if (!categoryConfig) {
      return null;
    }

    let html = '<div class="multilevel-sidebar">';
    
    // If this is a subcategory (has parent), show only this category with back button
    if (categoryConfig.parent) {
      const parentConfig = this.parsedMultilevelConfig[categoryConfig.parent];
      
      // Add current subcategory title with inline back button
      html += `<h3 class="category-title with-back">`;
      if (parentConfig) {
        html += `<a href="/c/${parentConfig.name.toLowerCase().replace(/\\s+/g, '-')}/${categoryConfig.parent}" class="back-link-inline">
          ${iconHTML("arrow-left")}
        </a>`;
      }
      html += `${categoryConfig.name}</h3>`;
      
      // Add items for this subcategory
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
      // This is a parent category, show it with all its children and their subitems
      // Don't add our own title since the original header will be visible
      
      // Show children with their subitems
      if (categoryConfig.children && categoryConfig.children.length > 0) {
        html += '<div class="subcategories"><ul>';
        categoryConfig.children.forEach(childId => {
          const childConfig = this.parsedMultilevelConfig[childId];
          if (childConfig) {
            html += `<li class="subcategory-item">
              <div class="subcategory-header">
                <a href="/c/${childConfig.name.toLowerCase().replace(/\\s+/g, '-')}/${childId}" class="subcategory-link">${childConfig.name}</a>
              </div>`;
            
            // Show items for this child category
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
    console.log("FixedSidebar - hiding other sections, keeping:", keepSectionName);
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
    console.log("FixedSidebar - showing all sections");
    const hiddenSections = document.querySelectorAll('.sidebar-section-wrapper.multilevel-hidden');
    hiddenSections.forEach(section => {
      section.style.display = '';
      section.classList.remove('multilevel-hidden');
    });
    
    // Restore all hidden headers
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
        // This is a subcategory (like Platform), hide the original header completely
        sectionHeader.style.display = 'none';
        sectionHeader.classList.add('multilevel-header-hidden');
        console.log("FixedSidebar - hiding header for subcategory");
      } else {
        // This is a parent category (like Product guides), keep header visible but mark it
        sectionHeader.style.display = '';
        sectionHeader.classList.remove('multilevel-header-hidden');
        console.log("FixedSidebar - keeping header for parent category");
      }
    }
  }

  findTargetSection(categoryId) {
    // This method determines which sidebar section (product-guides or implementation-guides)
    // should be used for the multilevel display
    
    // For now, we'll use a simple mapping - you can extend this logic
    // based on your category hierarchy
    const categoryConfig = this.parsedMultilevelConfig[categoryId];
    if (!categoryConfig) {
      return null;
    }
    
    // Check if this category or its parent matches known sections
    if (categoryConfig.name.toLowerCase().includes('product')) {
      return 'product-guides';
    }
    
    if (categoryConfig.name.toLowerCase().includes('implementation')) {
      return 'implementation-guides';
    }
    
    // Check parent category
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
    
    // Default fallback - you might want to make this configurable
    return 'product-guides';
  }

  @action
  setupContents() {
    schedule("afterRender", () => {
      // Check if we should use multilevel mode
      const currentCategoryId = this.getCurrentCategoryId();
      const multilevelConfig = this.parsedMultilevelConfig;
      const categoryConfig = currentCategoryId ? multilevelConfig[currentCategoryId] : null;
      
      console.log("FixedSidebar - setupContents:");
      console.log("- currentCategoryId:", currentCategoryId);
      console.log("- categoryConfig:", categoryConfig);
      
      if (categoryConfig) {
        // Use multilevel mode
        this.currentCategoryConfig = categoryConfig;
        this.multilevelContent = this.generateMultilevelContent(categoryConfig, currentCategoryId);
        
        // Find which section this category belongs to (product-guides or implementation-guides)
        const targetSectionName = this.findTargetSection(currentCategoryId);
        console.log("FixedSidebar - targetSectionName:", targetSectionName);
        
        if (targetSectionName) {
          // Hide all other sidebar sections
          this.hideOtherSections(targetSectionName);
          
          const targetElement = document.querySelector(
            `.sidebar-section-wrapper[data-section-name="${targetSectionName}"]`
          );
          
          if (targetElement) {
            // Hide or show the section header based on category type
            this.handleSectionHeader(targetElement, categoryConfig);
            
            // Remove existing content
            const existingContent = targetElement.querySelector('.custom-sidebar-section');
            if (existingContent) {
              existingContent.remove();
            }
            
            // Create new multilevel content element
            const multilevelElement = document.createElement('div');
            multilevelElement.className = 'custom-sidebar-section multilevel-section';
            multilevelElement.setAttribute('data-sidebar-name', targetSectionName);
            multilevelElement.innerHTML = this.multilevelContent;
            
            targetElement.appendChild(multilevelElement);
            
            console.log("FixedSidebar - Multilevel content inserted into:", targetSectionName);
          }
        }
        
        // Early return to avoid executing original behavior
        return;
      } else {
        // Show all sections normally
        this.showAllSections();
      }
      
      // Use original behavior
      this.contents.forEach(({ section }) => {
        const contentElement = document.querySelector(
          `.custom-sidebar-section[data-sidebar-name="${section}"]`
        );

        if (contentElement) {
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
}
