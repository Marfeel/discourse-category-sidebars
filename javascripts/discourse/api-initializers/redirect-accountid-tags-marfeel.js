import { apiInitializer } from "discourse/lib/api";
import { defaultRenderTag } from "discourse/lib/render-tag";

export default apiInitializer("1.6.0", (api) => {
  const customRenderer = (tag, params) => {
    const originalTag = defaultRenderTag(tag, params);
    let val = originalTag;

    if (tag.match(/^accountid-\d+$/)) {
      const accountId = tag.split('-')[1];
      // result returns <a href='/u/jonay.rodriguez/messages/tags/accountid-2201'  data-tag-name=accountid-2201 class='discourse-tag bullet'>accountid-2201</a>
      // need wrapper with 2 links
      // <div>
      //   <a href='https://www.hub.marfeel.com/?accountId=2201' target='_blank'><svg></svg></a>
      //   <a href='/u/jonay.rodriguez/messages/tags/accountid-2201'  data-tag-name=accountid-2201 class='discourse-tag bullet'>accountid-2201</a>

      const marfeelLink = document.createElement('a');

      marfeelLink.className = 'marfeel-link-to-hub';
      marfeelLink.href = `https://hub.marfeel.com/compass/editorial/?accountId=${accountId}`;
      marfeelLink.target = '_blank';
      marfeelLink.innerHTML = '<svg width="9" height="9" xmlns="http://www.w3.org/2000/svg"><use href="#mrf-marfeel"></use></svg>';

      val = `
        <div class='marfeel-tag-wrapper'>
          ${marfeelLink.outerHTML}
          ${originalTag}
        </div>
      `;
    }

    return val;
  };

  api.replaceTagRenderer(customRenderer);
});