import { Hm7FeaturePage } from './Hm7FeaturePage'
import { hm7PageConfig } from './Hm7PageConfigs'

@Entry
@Component
struct TenantMemberListPage {
  build() {
    Column() {
      Hm7FeaturePage({ config: hm7PageConfig('P214') })
    }
    .width('100%')
    .height('100%')
  }
}
