import { withPluginApi } from "discourse/lib/plugin-api";

// Utility function
function waitForElement(selector, callback) {
  const element = document.querySelector(selector);
  if (element) {
    callback(element);
    return;
  }

  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeType === Node.ELEMENT_NODE) {
          const foundElement = node.matches?.(selector) ? node : node.querySelector?.(selector);
          if (foundElement) {
            observer.disconnect();
            callback(foundElement);
            return;
          }
        }
      }
    }
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });
}

const ICON_SECTIONS = {
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

function addIconSections() {
  const customSidebarSections = document.querySelectorAll(
    ".sidebar-sections .custom-sidebar-section > details"
  );

  for (const section of customSidebarSections) {
    const sectionName = section.querySelector("summary")?.textContent.trim();
    const icon = ICON_SECTIONS[sectionName];

    if (icon && !section.querySelector(`.d-icon-${icon}`)) {
      section.classList.add(`mrf-sidebar-${icon}`);

      const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
      svg.classList.add("fa", "d-icon", "svg-icon", "prefix-icon", "svg-string", `d-icon-${icon}`);
      svg.setAttribute("viewBox", "0 0 512 512");

      const path = document.querySelector(`symbol#${icon}`);
      if (path) {
        svg.innerHTML = path.innerHTML;
        section.querySelector("summary").prepend(svg);
      }
    }
  }
}

export default {
  name: "sidebar-icons",

  initialize() {
    withPluginApi("0.11.1", (api) => {
      waitForElement(".sidebar-sections .custom-sidebar-section", addIconSections);

      document.addEventListener("sidebar:update-icons", addIconSections);

      api.onPageChange(() => {
        addIconSections();
      });

      api.cleanupStream(() => {
        document.removeEventListener("sidebar:update-icons", addIconSections);
      });
    });
  },
};
