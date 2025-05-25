import { withPluginApi } from "discourse/lib/plugin-api";
import { SidebarLoadingManager } from "../lib/sidebar-loading-manager";

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

let sidebarObserver = null;
let retryCount = 0;
const MAX_RETRIES = 20;
const RETRY_INTERVAL = 100;
const loadingManager = SidebarLoadingManager.getInstance();

function addIconSections() {
  const customSidebarSections = document.querySelectorAll(
    ".sidebar-sections .custom-sidebar-section > details"
  );

  let iconsAdded = 0;

  for (const section of customSidebarSections) {
    const summary = section.querySelector("summary");
    if (!summary) {
      continue;
    }

    const sectionName = summary.textContent.trim();
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
        summary.prepend(svg);

        // Add loaded class for smooth transition
        setTimeout(() => {
          svg.classList.add("icon-loaded");
        }, 10);

        iconsAdded++;
      }
    }
  }

  // Mark custom sections as loaded for smooth appearance
  for (const section of customSidebarSections) {
    const parentSection = section.closest(".custom-sidebar-section");
    if (parentSection) {
      const sectionName = parentSection.getAttribute("data-sidebar-name");
      if (sectionName) {
        loadingManager.markSectionAsLoaded(sectionName);
      } else {
        parentSection.classList.add("loaded");
      }
    }
  }

  return iconsAdded;
}

function waitForCustomSections() {
  const customSections = document.querySelectorAll(
    ".sidebar-sections .custom-sidebar-section > details"
  );

  if (customSections.length > 0) {
    const iconsAdded = addIconSections();
    if (iconsAdded > 0) {
      retryCount = 0; // Reset retry count on success
      return true;
    }
  }

  if (retryCount < MAX_RETRIES) {
    retryCount++;
    setTimeout(waitForCustomSections, RETRY_INTERVAL);
  } else {
    retryCount = 0; // Reset for next attempt
  }

  return false;
}

function setupSidebarObserver() {
  if (sidebarObserver) {
    sidebarObserver.disconnect();
  }

  const sidebarContainer = document.querySelector(".sidebar-sections");
  if (!sidebarContainer) {
    // If sidebar container doesn't exist yet, retry
    setTimeout(setupSidebarObserver, 100);
    return;
  }

  sidebarObserver = new MutationObserver((mutations) => {
    let shouldUpdateIcons = false;

    for (const mutation of mutations) {
      if (mutation.type === "childList") {
        // Check if custom sidebar sections were added
        for (const node of mutation.addedNodes) {
          if (node.nodeType === Node.ELEMENT_NODE) {
            if (node.classList?.contains("custom-sidebar-section") ||
                node.querySelector?.(".custom-sidebar-section")) {
              shouldUpdateIcons = true;
            }
          }
        }
      }
    }

    if (shouldUpdateIcons) {
      // Use a small delay to ensure DOM is fully updated
      setTimeout(() => {
        waitForCustomSections();
      }, 50);
    }
  });

  sidebarObserver.observe(sidebarContainer, {
    childList: true,
    subtree: true,
    attributes: false
  });
}

export default {
  name: "sidebar-icons",

  initialize() {
    withPluginApi("0.8.31", (api) => {
      // Set up observer when app starts
      api.onAppEvent("dom:loaded", () => {
        setupSidebarObserver();
        waitForCustomSections();
      });

      // Handle page changes
      api.onPageChange(() => {
        setupSidebarObserver();
        setTimeout(() => {
          waitForCustomSections();
        }, 100);
      });

      // Handle sidebar rendered events
      api.onAppEvent("sidebar:rendered", () => {
        setTimeout(() => {
          waitForCustomSections();
        }, 50);
      });

      // Listen for custom section added events
      window.addEventListener("sidebar:section-added", () => {
        setTimeout(() => {
          waitForCustomSections();
        }, 20);
      });

      // Initial setup
      setTimeout(() => {
        setupSidebarObserver();
        waitForCustomSections();
      }, 200);
    });
  }
};