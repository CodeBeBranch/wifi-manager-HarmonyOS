import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { appPreferences } from '../storage/AppPreferences';
import { runtimeSettings } from '../storage/RuntimeSettings';
import { sessionStore } from '../session/SessionStore';
import { themeStore } from '../storage/ThemeStore';
import { alertSocketClient } from '../network/AlertSocketClient';
import { deviceCommandPoller } from '../network/DeviceCommandPoller';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    alertSocketClient.stop();
    deviceCommandPoller.stop();
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');
    this.initializeAndLoad(windowStage);
  }

  private async initializeAndLoad(windowStage: window.WindowStage): Promise<void> {
    try {
      await appPreferences.initialize(this.context);
      await themeStore.initialize(this.context);
      await runtimeSettings.initialize();
      await sessionStore.initialize();
    } catch (error) {
      hilog.error(
        DOMAIN,
        'wifi-manager',
        'Failed to initialize local session: %{public}s',
        error instanceof Error ? error.message : 'unknown'
      );
    }
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    alertSocketClient.resume();
    deviceCommandPoller.resume();
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    alertSocketClient.pause();
    deviceCommandPoller.pause();
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
