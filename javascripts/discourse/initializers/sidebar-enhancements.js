import { withPluginApi } from "discourse/lib/plugin-api";

function updateSidebarActiveLink() {
  const segments = window.location.pathname.split("/");
  let topicId = "";

  for (const segment of segments) {
    if (segment.match(/^\d+$/)) {
      topicId = segment;
      break;
    }
  }

  const activeItem = document.querySelector("li a.active:not(.sidebar-section-link)");
  if (activeItem) {
    activeItem.classList.remove("active");
    let parent = activeItem.closest("details");
    while (parent) {
      if (parent.tagName === "DETAILS") {
        parent.open = false;
      }
      parent = parent.parentElement.closest("details");
    }
  }

  const currentSidebarItem = document.querySelector(
    `.sidebar-sections li > a[href$='/${topicId}']:not(.active):not(.sidebar-section-link)`
  );
  if (currentSidebarItem) {
    currentSidebarItem.classList.add("active");
    let element = currentSidebarItem.closest("details");
    while (element) {
      if (element.tagName === "DETAILS") {
        element.open = true;
      }
      element = element.parentElement.closest("details");
    }
  }
}

function updateCustomSidebar() {
  const sidebarSections = document.querySelectorAll(".sidebar-section-wrapper[data-section-name]");

  for (const section of sidebarSections) {
    const sidebarName = section.dataset.sectionName;
    const customSidebar = document.querySelector(
      `.sidebar-section-wrapper .custom-sidebar-section[data-sidebar-name="${sidebarName}"]`
    );

    if (!customSidebar) {
      const mainOutlet = document.querySelector("#main-outlet");
      const customSidebarClone = mainOutlet?.querySelector(
        `.custom-sidebar-section[data-sidebar-name="${sidebarName}"]`
      );
      if (customSidebarClone) {
        const clonedSidebar = customSidebarClone.cloneNode(true);
        section.appendChild(clonedSidebar);
      }
    }
  }
}

function observeHamburgerMobile(mutations) {
  for (const mut of mutations) {
    if (mut.type === "childList") {
      updateCustomSidebar();
      updateSidebarActiveLink();

      document.dispatchEvent(new CustomEvent("sidebar:update-icons"));
    }
  }
}

export default {
  name: "sidebar-functionality",

  initialize() {
    withPluginApi("0.11.1", (api) => {
      const { debounce } = window.MarfeelCommunityUtils;

      const sideObserver = new MutationObserver(debounce(updateSidebarActiveLink, 100));
      const topicBody = document.querySelector("#main-outlet-wrapper");
      if (topicBody) {
        sideObserver.observe(topicBody, { childList: true, subtree: true });
      }

      const fixedObserver = new MutationObserver(debounce(updateCustomSidebar, 100));
      fixedObserver.observe(document.body, { childList: true, subtree: true });

      if (document.body.classList.contains("mobile-view")) {
        const { waitForElement } = window.MarfeelCommunityUtils;
        waitForElement(".mobile-view .panel", (mobilePanel) => {
          const observerSidebarMobile = new MutationObserver(debounce(observeHamburgerMobile, 100));
          observerSidebarMobile.observe(mobilePanel, { childList: true, subtree: true });
        });
      }

      api.onPageChange(() => {
        updateSidebarActiveLink();
        updateCustomSidebar();
      });

      api.cleanupStream(() => {
        sideObserver?.disconnect();
        fixedObserver?.disconnect();
      });
    });
  },
};
