import { apiInitializer } from "discourse/lib/api";
import { defaultRenderTag } from "discourse/lib/render-tag";

export default apiInitializer("1.6.0", (api) => {
  const customRenderer = (tag, params) => {
    const result = defaultRenderTag(tag, params);

    // eslint-disable-next-line no-console
    console.log('result', result);

    return result;
  };

  api.replaceTagRenderer(customRenderer);
});