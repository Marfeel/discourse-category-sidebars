import { typeOf } from "@ember/utils";
import $ from "jquery";
import { apiInitializer } from "discourse/lib/api";
import { defaultRenderTag } from "discourse/lib/render-tag";

export default apiInitializer("0.11.1", (api) => {
  const customRenderer = (tag, params) => {
    const result = defaultRenderTag(tag, params);
    const text = $(result).html();

    // eslint-disable-next-line no-console
    console.log('text', text );

    function isAccountIdTag(tagId) {
      return tagId.match(/^accountid-\d+$/);
    }

    if (isAccountIdTag(tag)) {
      const accountId = tag.split('-')[1];
      // result returns <a href='/u/jonay.rodriguez/messages/tags/accountid-2201'  data-tag-name=accountid-2201 class='discourse-tag bullet'>accountid-2201</a>
      // we need to change href to https://www.hub.marfeel.com/?accountId=2201

      const newHref = `https://www.hub.marfeel.com/?accountId=${accountId}`;

      result.replace('href=\'', `href='${newHref}`);
    }

    return result;
  };

  api.replaceTagRenderer(customRenderer);
});