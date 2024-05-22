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
      marfeelLink.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="9" height="9" fill="none"><g fill-rule="evenodd" clip-path="url(#mrf-logo)" clip-rule="evenodd"><path fill="url(#mrf-logoB)" d="m4.118 3.193.963 3.391c.102.357-.123.723-.502.819l-3.087.778c-.38.096-.604.462-.502.819L.024 5.61c-.101-.356.124-.722.503-.818l3.087-.778c.379-.096.605-.464.504-.82Z"/><path fill="url(#mrf-logoC)" d="m7.988 0 .965 3.387c.101.357-.124.723-.502.818l-3.088.778c-.379.096-.606.464-.505.82l-.962-3.389c-.102-.356.123-.723.502-.818L7.485.818c.38-.095.604-.462.503-.818Z"/></g><defs><linearGradient id="mrf-logoB" x1="357.42" x2="541.884" y1="583.856" y2="207.733" gradientUnits="userSpaceOnUse"><stop stop-color="#A6D951"/><stop offset="1" stop-color="#86C424"/></linearGradient><linearGradient id="mrf-logoC" x1="514.448" x2="217.466" y1="67.079" y2="488.257" gradientUnits="userSpaceOnUse"><stop stop-color="#FFC551"/><stop offset="1" stop-color="#F7941E"/></linearGradient><clipPath id="mrf-logo"><path fill="#fff" d="M0 0h9v9H0z"/></clipPath></defs></svg>';

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