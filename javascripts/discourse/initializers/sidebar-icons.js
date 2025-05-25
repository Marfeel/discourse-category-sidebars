import { schedule } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";

const iconSections = {
  Platform: "mrf-apps",
  Editorial: "mrf-editorial",
  Audience: "mrf-users",
  Engagement: "mrf-heart",
  Subscriptions: "mrf-subscriptions",
  Advertisement: "mrf-comments-lines",
  Social: "mrf-comments",
  Affiliation: "mrf-shopping-bag",
  "User settings": "mrf-user-settings",
  SDKs: "mrf-apps",
  "Editorial metadata": "mrf-apps",
  Multimedia: "mrf-play",
  Experiences: "mrf-map-pin",
  "Data Exports": "mrf-shuffle",
  "Marfeel API": "mrf-bolt",
  "Organization settings": "mrf-user-settings",
  Debugging: "mrf-apps",
  Recommender: "mrf-recommender",
  Amplify: "mrf-amplify"
};

let iconsInitialized = false;

function addIconSections() {
  const customSidebarSections = document.querySelectorAll(
    ".sidebar-sections .custom-sidebar-section > details"
  );

  for (const section of customSidebarSections) {
    const sectionName = section.querySelector("summary").textContent.trim();
    const icon = iconSections[sectionName];

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
  }
  iconsInitialized = true;
}

export default {
  name: "sidebar-icons",

  initialize() {
    withPluginApi("0.8.31", (api) => {
      api.onAppEvent("dom:clean", () => {
        iconsInitialized = false;
      });

      document.addEventListener('custom-sections-ready', () => {
        console.log("Custom sections are ready, adding icons...", iconsInitialized);
        if (!iconsInitialized) {
          schedule("afterRender", () => {
            addIconSections();
          });
        }
      });
    });
  }
};