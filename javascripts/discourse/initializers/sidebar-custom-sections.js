import { withPluginApi } from "discourse/lib/plugin-api";

let sectionsInitialized = false;
let pendingCallbacks = [];

window.sidebarCustomSections = {
  onSectionsReady: (callback) => {
    if (sectionsInitialized) {
      callback();
    } else {
      pendingCallbacks.push(callback);
    }
  }
};

function executeCallbacks() {
  sectionsInitialized = true;
  console.log("Custom sections are ready, sections initialized:");

  pendingCallbacks.forEach(callback => {
    try {
      callback();
    } catch (error) {
      console.error('Error executing sidebar callback:', error);
    }
  });
  pendingCallbacks = [];

  window.dispatchEvent(new CustomEvent('sidebar-sections-ready'));
}

function updateCustomSidebar() {
  const sidebarSections = document.querySelectorAll(
    ".sidebar-section-wrapper[data-section-name]"
  );
  sidebarSections.forEach((section) => {
    const sidebarName = section.dataset.sectionName;
    const customSidebar = document.querySelector(
      `.sidebar-section-wrapper .custom-sidebar-section[data-sidebar-name="${sidebarName}"]`
    );
    if (!customSidebar) {
      const mainOutlet = document.querySelector("#main-outlet");
      const customSidebarClone = mainOutlet.querySelector(
        `.custom-sidebar-section[data-sidebar-name="${sidebarName}"]`
      );
      if (customSidebarClone) {
        const clonedSidebar = customSidebarClone.cloneNode(true);
        section.appendChild(clonedSidebar);
      }
    }
  });

  if (window.MarfeelCommunityUtils.waitForElement) {
    window.MarfeelCommunityUtils.waitForElement('.sidebar-sections .custom-sidebar-section', () => {
      executeCallbacks();
    });
  } else {
    // Fallback si waitForElement no está disponible
    requestAnimationFrame(() => {
      executeCallbacks();
    });
  }
}

export default {
  name: "custom-sidebar-sections",

  initialize() {
    withPluginApi("0.8.31", (api) => {
      api.onAppEvent("dom:clean", () => {
        sectionsInitialized = false;
        pendingCallbacks = [];
      });

      api.onAppEvent("sidebar:rendered", () => {
        if (!sectionsInitialized) {
          updateCustomSidebar();
        }
      });

      if (!sectionsInitialized) {
        updateCustomSidebar();
      }
    });
  },
};