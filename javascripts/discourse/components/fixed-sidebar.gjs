import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";

export default class FixedSidebar extends Component {
  @service siteSettings;
  @service router;
  @tracked contents = [];
  @tracked loading = true;
  fixedObserver = null;

  constructor() {
    super(...arguments);
    this.fetchContents();
  }

  <template>
    <div {{didUpdate this.setupContents this.router}}>
      {{#each this.contents as |content|}}
        <div
          class="custom-sidebar-section"
          data-sidebar-name={{content.section}}
        >
          {{#unless this.loading}}
            {{htmlSafe content.content}}
          {{/unless}}
        </div>
      {{/each}}
    </div>
  </template>

  get fixedSettings() {
    const setupFixed = settings.setup_fixed.split("|").map((entry) => {
      const [section, postId] = entry.split(",");
      return { section: section.trim(), postId: postId.trim() };
    });

    return setupFixed;
  }

  @action
  async fetchContents() {
    this.loading = true;
    try {
      const promises = this.fixedSettings.map(async (setting) => {
        const response = await ajax(`/t/${setting.postId}.json`);
        return {
          section: setting.section,
          content: response.post_stream.posts[0].cooked,
        };
      });

      this.contents = await Promise.all(promises);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(
        "Error fetching fixed content for multiple sidebars:",
        error
      );
    } finally {
      this.loading = false;
    }
  }

  @action
  setupContents() {
    console.log(this.siteSettings);
    schedule("afterRender", () => {
      this.contents.forEach(({ section }) => {
        const targetElement = document.querySelector(
          `.sidebar-section-wrapper[data-section-name="${section}"]`
        );
        if (targetElement) {
          const contentElement = document.querySelector(
            `.custom-sidebar-section[data-sidebar-name="${section}"]`
          );
          if (contentElement) {
            targetElement.appendChild(contentElement);
          }
        }
      });
    });
  }
}
