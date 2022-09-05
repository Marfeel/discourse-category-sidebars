import { getOwner } from "discourse-common/lib/get-owner";
import { ajax } from "discourse/lib/ajax";
import { cleanDOM } from "discourse/lib/clean-dom";
import PostCooked from "discourse/widgets/post-cooked";
import RawHtml from "discourse/widgets/raw-html";
import { createWidget } from "discourse/widgets/widget";

function defaultSettings() {
  return {};
}

function parseSetups(raw) {
  const parsed = {};
  raw.split("|").forEach((setting) => {
    const [category, value] = setting.split(",").map((s) => s.trim());
    parsed[category] = parsed[category] || defaultSettings();
    parsed[category]["post"] = value;
  });
  return parsed;
}

function createSidebar(taxonomy, isCategory) {
  const setup = isCategory ? setupByCategory[taxonomy] : setups[taxonomy];
  const post = [this.getPost(setup["post"])];
  this.state.posts = post;

  if (!this.state.posts || this.state.posts.length === 0) {
    return;
  }

  return new RawHtml({
    html: `<div class="category-sidebar-contents category-sidebar-${taxonomy}">${this.state.posts}</div>`
  });
}

const postCache = {};
const setups = parseSetups(settings.setupDetails);
const setupByCategory = parseSetups(settings.setup_by_category_id);

createWidget("details-sidebar", {
  tagName: "div.sticky-sidebar",
  buildKey: () => "details-sidebar",

  defaultState() {
    return { posts: null };
  },

  init() {
    let sidebarWrapper =
      document.getElementsByClassName("category-sidebar")[0] || 0;
    let headerHeight =
      document.getElementsByClassName("d-header-wrap")[0].offsetHeight || 0;
    let sidebarTop = headerHeight + 20 + "px";
    let sidebarMaxHeight = "calc(100vh - " + (headerHeight + 40) + "px)";
    if (sidebarWrapper) {
      sidebarWrapper.style.maxHeight = sidebarMaxHeight;
      sidebarWrapper.style.top = settings.stick_on_scroll ? sidebarTop : undefined;
      sidebarWrapper.style.position = settings.stick_on_scroll ? "sticky" : "";
    }

    document
      .querySelector("body")
      .classList.add("custom-sidebar", "sidebar-" + settings.sidebar_side);
    document
      .querySelector("#main-outlet > .container+div")
      .classList.add("with-sidebar", settings.sidebar_side);
  },

  html() {
    const router = getOwner(this).lookup("router:main");
    const currentRouteParams = router.currentRoute.parent.params;
    const currentCategoryId = router.currentRoute?.parent?.attributes?.category_id || 0;
    const isDetailTopic = currentRouteParams.hasOwnProperty(
      "slug"
    );

    router.on("routeDidChange", () => {
      cleanDOM(this);
    });

    let prevURL = "";

    const observer = new MutationObserver(() => {
      if (location.href !== prevURL && (/\/t\//.test(location.href))) {
        prevURL = location.href;
        const rt = getOwner(this).lookup("router:main");
        const currentRT = rt.currentRoute.parent.params;
        const activeItem = document.querySelector("li a.active");

        if (activeItem) {
          activeItem.classList.remove("active");
          if (activeItem.closest("details")) {
            activeItem.closest("details").open = false;
          }
        }
        const currentSidebarItem = document.querySelector(
          "li a[href*='" + currentRT.id + "']:not(.active)"
        );
        if (currentSidebarItem) {
          currentSidebarItem.classList.add("active");
          if (currentSidebarItem.closest("details")) {
            currentSidebarItem.closest("details").setAttribute("open", "");
          }
        }
      }
    });

    const topicBody = document.getElementById("main-outlet");
    observer.observe(topicBody, { childList: true, subtree: true });

    if (setups["all"] && !isDetailTopic) {
      return createSidebar.call(this, "all");
    } else if (isDetailTopic) {
      const detailsSlug = currentRouteParams.slug

      if (detailsSlug && setups[detailsSlug]) {
        return createSidebar.call(this, detailsSlug, false);
      } else if (currentCategoryId && setupByCategory[currentCategoryId]) {
        return createSidebar.call(this, currentCategoryId, true);
      } else if (settings.inherit_parent_sidebar) {
        console.log(setupByCategory, 'category');
        getPostFromParent(178);
      }
    }
  },

  getPost(id) {
    if (!postCache[id]) {
      ajax(`/t/${id}.json`).then((response) => {
        postCache[id] = new PostCooked({
          cooked: response.post_stream.posts[0].cooked,
        });
        this.scheduleRerender();
      });
    }
    return postCache[id];
  },

  getPostFromParent(id) {
    if (!postCache[id]) {
      ajax(`/c/${id}.json`).then((response) => {
        console.log(response, 'response');
      });
    }
  }
});