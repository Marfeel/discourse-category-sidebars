import Component from "@ember/component";
import { classNames } from "@ember-decorators/component";
import CategorySidebar0 from "../../components/category-sidebar";
import FixedSidebar from "../../components/fixed-sidebar";

@classNames("above-main-container-outlet", "category-sidebar")
export default class CategorySidebarConnector extends Component {
  <template>
    <FixedSidebar />
    <CategorySidebar0 />
  </template>
}
