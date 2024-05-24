import { apiInitializer } from "discourse/lib/api";
import { defaultRenderTag } from "discourse/lib/render-tag";

export default apiInitializer("1.6.0", (api) => {
  const customRenderer = (tag, params) => {
    let originalTag = defaultRenderTag(tag, params);

    if (tag.match(/^accountid-\d+$/)) {
      const accountId = tag.split('-')[1];
      const marfeelLink = document.createElement('a');

      marfeelLink.className = 'marfeel-link-to-hub';
      marfeelLink.href = `https://hub.marfeel.com/compass/editorial/?accountId=${accountId}`;
      marfeelLink.target = '_blank';
      marfeelLink.innerHTML = '<svg width="9" height="9" xmlns="http://www.w3.org/2000/svg"><use href="#mrf-marfeel"></use></svg>';

      const customTag = originalTag.replace('accountid-', '');

      console.log({ customTag, originalTag });

      let val = `
        <div class='marfeel-tag-wrapper'>
          ${marfeelLink.outerHTML}
          ${customTag}
        </div>
      `;

      return val;
    }

    return originalTag;
  };

  api.replaceTagRenderer(customRenderer);
});