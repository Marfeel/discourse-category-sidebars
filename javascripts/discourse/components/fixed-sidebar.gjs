import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { inject as service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { ajax } from "discourse/lib/ajax";

export default class FixedSidebar extends Component {
  @service siteSettings;
  @tracked contents = [];
  @tracked loading = true;

  constructor() {
    super(...arguments);
    this.fetchContents();
  }

  <template>
    {{#each this.contents as |content|}}
      <div class="sidebar-section" data-section-name={{content.section}}>
        {{#unless this.loading}}
          {{htmlSafe this.sidebarContent}}
        {{/unless}}
      </div>
    {{/each}}
  </template>

  get fixedSettings() {
    const setupFixed = settings.setup_fixed.split("|").map((entry) => {
      const [section, postId] = entry.split(",");
      return { section: section.trim(), postId: postId.trim() };
    });

    console.log("setupFixed", setupFixed);

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
    schedule("afterRender", this, () => {
      this.contents.forEach(({ section, content }) => {
        const targetElement = document.querySelector(
          `[data-section-name="${section}"]`
        );
        if (targetElement) {
          // eslint-disable-next-line no-console
          console.log("targetElement", targetElement);
          const divElement = document.createElement("div");
          divElement.innerHTML = content;
          targetElement.appendChild(divElement);
          const ulElement = targetElement.querySelector(
            "ul.sidebar-section-content"
          );

          if (ulElement) {
            ulElement.style.display = "none";
          }
        }
      });
    });
  }
}