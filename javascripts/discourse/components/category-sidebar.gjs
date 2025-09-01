import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import bodyClass from "discourse/helpers/body-class";
import { ajax } from "discourse/lib/ajax";
import Category from "discourse/models/category";

export default class CategorySidebar extends Component {
  @service router;
  @service siteSettings;
  @service site;

  @tracked sidebarContent;
  @tracked loading = true;
  @tracked lastFetchedCategory = null;
  @tracked multilevelContent = null;
  @tracked currentCategoryConfig = null;
  @tracked navigationHistory = [];

  <template>
    {{#if this.shouldShowSidebar}}
      {{bodyClass "custom-sidebar"}}
      {{bodyClass (concat "sidebar-" settings.sidebar_side)}}
      <div
        class="category-sidebar"
        {{didInsert this.initializeSidebar}}
        {{didUpdate this.updateSidebar this.category}}
      >
        <div class="sticky-sidebar">
          <div
            class="category-sidebar-contents"
            data-category-sidebar={{this.category.slug}}
          >
            <div class="cooked">
              {{#unless this.loading}}
                {{#if this.isMultilevelMode}}
                  {{htmlSafe this.multilevelContent}}
                {{else}}
                  {{htmlSafe this.sidebarContent}}
                {{/if}}
              {{/unless}}
              <ConditionalLoadingSpinner @condition={{this.loading}} />
            </div>
          </div>
        </div>
      </div>
    {{/if}}
  </template>

  get parsedSetting() {
    return settings.setup.split("|").reduce((result, setting) => {
      const [category, value] = setting
        .split(",")
        .map((postID) => postID.trim());
      result[category] = { post: value };
      return result;
    }, {});
  }

  get isTopRoute() {
    const topMenu = this.siteSettings.top_menu;

    if (!topMenu) {
      return false;
    }

    const targets = topMenu.split("|").map((opt) => `discovery.${opt}`);
    const filteredTargets = targets.filter(
      (item) => item !== "discovery.categories"
    );

    return filteredTargets.includes(this.router.currentRouteName);
  }

  get categoryIdTopic() {
    return this.router?.currentRoute?.parent?.attributes?.category_id;
  }

  get categorySlugPathWithID() {
    return this.router?.currentRoute?.params?.category_slug_path_with_id;
  }

  get category() {
    return this.categorySlugPathWithID
      ? Category.findBySlugPathWithID(this.categorySlugPathWithID)
      : null;
  }

  get topicCategory() {
    return this.categoryIdTopic
      ? Category.findById(this.categoryIdTopic)
      : null;
  }

  get matchedSetting() {
    if (this.parsedSetting["all"] && this.isTopRoute) {
      // if this is a top_menu route, use the "all" setting
      return this.parsedSetting["all"];
    } else if (this.categorySlugPathWithID) {
      const categorySlug = this.category.slug;
      const parentCategorySlug = this.category.parentCategory?.slug;

      // if there's a setting for this category, use it
      if (categorySlug && this.parsedSetting[categorySlug]) {
        return this.parsedSetting[categorySlug];
      }

      // if there's not a setting for this category
      // check the parent, and maybe use that
      if (
        settings.inherit_parent_sidebar &&
        parentCategorySlug &&
        this.parsedSetting[parentCategorySlug]
      ) {
        return this.parsedSetting[parentCategorySlug];
      }
    } else if (this.categoryIdTopic) {
      const topicCategorySlug = this.topicCategory?.slug;
      const parentTopicCategorySlug = Category.findById(
        this.topicCategory?.parent_category_id
      )?.slug;

      if (topicCategorySlug && this.parsedSetting[topicCategorySlug]) {
        return this.parsedSetting[topicCategorySlug];
      }

      if (
        settings.inherit_parent_sidebar &&
        parentTopicCategorySlug &&
        this.parsedSetting[parentTopicCategorySlug]
      ) {
        return this.parsedSetting[parentTopicCategorySlug];
      }
    }
  }

  @action
  async fetchPostContent() {
    const currentCategory =
      this.category ||
      Category.findById(this.topicCategory?.parent_category_id);

    // Check if the category has changed
    if (
      this.lastFetchedCategory === currentCategory?.id ||
      this.lastFetchedCategory === currentCategory?.parent_category_id
    ) {
      // If not, skip fetching
      return;
    }

    this.loading = true;
    this.lastFetchedCategory = currentCategory?.id;

    try {
      if (this.matchedSetting) {
        const response = await ajax(`/t/${this.matchedSetting.post}.json`);
        this.sidebarContent = response.post_stream.posts[0].cooked;
      }
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Error fetching post for category sidebar:", error);
    } finally {
      this.loading = false;
    }

  }

  generateMultilevelContent() {
    if (!this.currentCategoryConfig) {
      return;
    }

    let html = '<div class="multilevel-sidebar">';
    
    // Add back button if this is a subcategory
    if (this.currentCategoryConfig.parent) {
      const parentConfig = this.parsedMultilevelConfig[this.currentCategoryConfig.parent];
      if (parentConfig) {
        html += `<div class="back-button">
          <a href="/c/${parentConfig.name.toLowerCase().replace(/\\s+/g, '-')}/${this.currentCategoryConfig.parent}" class="back-link">
            <i class="fa fa-arrow-left"></i> Back to ${parentConfig.name}
          </a>
        </div>`;
      }
    }

    // Add current category title
    html += `<h3 class="category-title">`;
    if (this.currentCategoryConfig.icon) {
      html += `<i class="fa fa-${this.currentCategoryConfig.icon}"></i> `;
    }
    html += `${this.currentCategoryConfig.name}</h3>`;

    // Add children categories if any
    if (this.currentCategoryConfig.children && this.currentCategoryConfig.children.length > 0) {
      html += '<div class="subcategories"><h4>Categories</h4><ul>';
      this.currentCategoryConfig.children.forEach(childId => {
        const childConfig = this.parsedMultilevelConfig[childId];
        if (childConfig) {
          html += `<li class="subcategory-item">
            <a href="/c/${childConfig.name.toLowerCase().replace(/\\s+/g, '-')}/${childId}" class="subcategory-link">`;
          if (childConfig.icon) {
            html += `<i class="fa fa-${childConfig.icon}"></i> `;
          }
          html += `${childConfig.name}</a>
          </li>`;
        }
      });
      html += '</ul></div>';
    }

    // Add category items if any
    if (this.currentCategoryConfig.items && this.currentCategoryConfig.items.length > 0) {
      html += '<div class="category-items"><h4>Topics</h4><ul>';
      this.currentCategoryConfig.items.forEach(item => {
        html += `<li class="category-item">
          <a href="${item.url}" class="item-link">${item.title}</a>
        </li>`;
      });
      html += '</ul></div>';
    }

    html += '</div>';
    this.multilevelContent = html;
  }
}
