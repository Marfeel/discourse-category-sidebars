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

      const wrapper = document.createElement('div');
      const originalTagNode = document.createElement('a');
      const marfeelLink = document.createElement('a');

      wrapper.className = 'marfeel-tag-wrapper';

      marfeelLink.className = 'marfeel-link-to-hub';
      marfeelLink.href = `https://hub.marfeel.com/compass/editorial/?accountId=${accountId}`;
      marfeelLink.target = '_blank';
      marfeelLink.innerHTML = '<svg xmlns="http://www.w3.org/2000/svg" width="12" height="12" fill="none"><g fill-rule="evenodd" clip-path="url(#mrf-logo)" clip-rule="evenodd"><path fill="url(#b)" d="m5.49 4.258 1.285 4.521c.136.476-.164.964-.67 1.092L1.99 10.909c-.505.127-.805.616-.67 1.091L.033 7.481c-.136-.475.164-.964.67-1.091l4.116-1.038c.505-.128.807-.619.672-1.094Z"/><path fill="url(#c)" d="m10.65 0 1.287 4.516c.135.475-.164.964-.67 1.091L7.151 6.644c-.505.128-.809.619-.673 1.094l-1.284-4.52c-.135-.474.165-.963.67-1.09l4.117-1.037c.505-.128.805-.616.67-1.091Z"/></g><defs><linearGradient id="b" x1="476.559" x2="722.513" y1="778.474" y2="276.977" gradientUnits="userSpaceOnUse"><stop stop-color="#A6D951"/><stop offset="1" stop-color="#86C424"/></linearGradient><linearGradient id="c" x1="685.931" x2="289.955" y1="89.438" y2="651.009" gradientUnits="userSpaceOnUse"><stop stop-color="#FFC551"/><stop offset="1" stop-color="#F7941E"/></linearGradient><clipPath id="mrf-logo"><path fill="#fff" d="M0 0h12v12H0z"/></clipPath></defs></svg>';

      originalTagNode.outerHTML = originalTag;

      wrapper.appendChild(marfeelLink);
      wrapper.appendChild(originalTagNode);

      val = wrapper.outerHTML;
    }

    return val;
  };

  api.replaceTagRenderer(customRenderer);
});