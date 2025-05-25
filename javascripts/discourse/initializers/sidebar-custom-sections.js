import { schedule } from '@ember/runloop';
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

  sectionsInitialized = true;

  console.log("Custom sections are ready, sections initialized:");

  requestAnimationFrame(() => {
    pendingCallbacks.forEach(callback => {
      try {
        callback();
      } catch (error) {
        console.error('Error executing sidebar callback:', error);
      }
    });
    pendingCallbacks = [];

    window.dispatchEvent(new CustomEvent('sidebar-sections-ready'));
  });
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
          schedule("afterRender", () => {
            updateCustomSidebar();
          });
        }
      });

      schedule("afterRender", () => {
        if (!sectionsInitialized) {
          updateCustomSidebar();
        }
      });
    });
  },
};