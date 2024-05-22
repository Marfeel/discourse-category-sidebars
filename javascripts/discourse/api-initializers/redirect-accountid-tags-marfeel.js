import { apiInitializer } from "discourse/lib/api";
import { defaultRenderTag } from "discourse/lib/render-tag";

export default apiInitializer("1.6.0", (api) => {
  const customRenderer = (tag, params) => {
    const result = defaultRenderTag(tag, params);
    let val = result;

    // eslint-disable-next-line no-console
    console.log('result', result, { tag });

    function isAccountIdTag(tagId) {
      return tagId.match(/^accountid-\d+$/);
    }

    if (isAccountIdTag(tag)) {
      const accountId = tag.split('-')[1];
      // result returns <a href='/u/jonay.rodriguez/messages/tags/accountid-2201'  data-tag-name=accountid-2201 class='discourse-tag bullet'>accountid-2201</a>
      // we need to change href to https://www.hub.marfeel.com/?accountId=2201

      const newHref = `https://hub.marfeel.com/compass/editorial/?accountId=${accountId}`;
      const hrefRegex = /href='[^']*'/;

      val = result.replace(hrefRegex, `href='${newHref} target='_blank'`);
    }

    // eslint-disable-next-line no-console
    console.log({ result, val });

    return val;
  };

  api.replaceTagRenderer(customRenderer);
});