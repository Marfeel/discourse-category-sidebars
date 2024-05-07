import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { inject as service } from "@ember/service";
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

  element = null;
  observer = null;

  <template>
    {{#if this.matchedSetting}}
      {{bodyClass "custom-sidebar"}}
      {{bodyClass (concat "sidebar-" settings.sidebar_side)}}
      <div
        class="category-sidebar"
        {{didInsert this.fetchPostContent}}
        {{didUpdate this.fetchPostContent this.category}}
      >
        <div class="sticky-sidebar">
          <div
            class="category-sidebar-contents"
            data-category-sidebar={{this.category.slug}}
            {{didInsert this.setupObserver}}
            {{didUpdate this.updateActiveLinks this.router.currentRoute}}
          >
            <div class="cooked">
              {{#unless this.loading}}
                {{htmlSafe this.sidebarContent}}
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
    return this.categoryIdTopic ? Category.findById(this.categoryIdTopic) : null;
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
    const currentCategory = this.category || Category.findById(
        this.topicCategory?.parent_category_id
      );

    // Check if the category has changed
    if (this.lastFetchedCategory === currentCategory?.id) {
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

    return this.sidebarContent;
  }

  @action
  setupObserver(element) {
    this.element = element;
    this.observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        console.log('mutation');
          this.updateActiveLinks(this.element);
      });
    });

    this.observer.observe(document.getElementById("main-outlet"), {
      childList: true,
      subtree: true,
    });

  }

  @action
  updateActiveLinks(element) {
    this.element = element;
    const activeItem = this.element.querySelector('li a.active:not(.sidebar-section-link)');

    console.log('activeItem', activeItem);

    if (activeItem) {
      activeItem.classList.remove("active");
      const parent = activeItem.closest("details");
      const grandParent = parent ? parent.parentNode : null;
      const greatGrandParent = grandParent ? grandParent.parentNode : null;

      if (parent && !grandParent) {
        parent.open = false;
      }
      if (parent && grandParent) {
        parent.open = false;
        grandParent.open = false;
      }
      if (parent && grandParent && greatGrandParent) {
        parent.open = false;
        grandParent.open = false;
        greatGrandParent.open = false;
      }
    }

    const currentSidebarItem = this.element.querySelector(`li a[href*='${this.router?.currentRoute?.parent?.params?.id}']:not(.active):not(.sidebar-section-link)`);

    const allLinks = this.element.querySelectorAll("li a");
    allLinks.forEach((link) => {
      link.classList.remove("active");
      if (link.href === window.location.href) {
        link.classList.add("active");
      }
    });

    if (currentSidebarItem) {
      currentSidebarItem.classList.add("active");
      const parent = currentSidebarItem.closest("details");
      const grandParent = parent ? parent.parentNode : null;
      const greatGrandParent = grandParent ? grandParent.parentNode : null;

      if (parent && !grandParent) {
        parent.open = true;
      }
      if (parent && grandParent) {
        parent.open = true;
        grandParent.open = true;
      }
      if (parent && grandParent && greatGrandParent) {
        parent.open = true;
        grandParent.open = true;
        greatGrandParent.open = true;
      }
    }
  }

  willDestroy() {
    if (this.observer) {
      this.observer.disconnect();
    }
  }
}
