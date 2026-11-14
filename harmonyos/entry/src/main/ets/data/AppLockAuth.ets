// 系统用户认证（@kit.UserAuthenticationKit）：统一认证控件，面容 / 指纹 / 锁屏密码任选。
// authType 含 PIN，所以生物识别失败或锁定时总能改用锁屏密码，只要设备设了密码就一定能解开。
import { userAuth } from '@kit.UserAuthenticationKit';
import { cryptoFramework } from '@kit.CryptoArchitectureKit';
import { AppLockAuthResult } from './AppLock';

// 设备是否设了锁屏密码（生物识别都以它为前提）。
export function appLockAvailable(): boolean {
  try {
    userAuth.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1);
    return true;
  } catch (_) {
    return false;
  }
}

function challenge(): Uint8Array {
  try {
    return cryptoFramework.createRandom().generateRandomSync(16).data;
  } catch (_) {
    // 本地解锁不校验令牌，挑战值只是控件的必填项
    return new Uint8Array(16);
  }
}

export function appLockAuthenticate(title: string): Promise<AppLockAuthResult> {
  return new Promise<AppLockAuthResult>((resolve: (result: AppLockAuthResult) => void) => {
    let instance: userAuth.UserAuthInstance | undefined = undefined;
    try {
      const authParam: userAuth.AuthParam = {
        challenge: challenge(),
        authType: [userAuth.UserAuthType.FACE, userAuth.UserAuthType.FINGERPRINT, userAuth.UserAuthType.PIN],
        authTrustLevel: userAuth.AuthTrustLevel.ATL1
      };
      const widgetParam: userAuth.WidgetParam = { title: title };
      const created = userAuth.getUserAuthInstance(authParam, widgetParam);
      instance = created;
      created.on('result', {
        onResult: (result: userAuth.UserAuthResult) => {
          try {
            created.off('result');
          } catch (_) {
          }
          resolve(mapResult(result.result));
        }
      });
      created.start();
    } catch (_) {
      try {
        instance?.off('result');
      } catch (_) {
      }
      resolve(appLockAvailable() ? AppLockAuthResult.FAILED : AppLockAuthResult.UNAVAILABLE);
    }
  });
}

function mapResult(code: number): AppLockAuthResult {
  if (code === userAuth.UserAuthResultCode.SUCCESS) return AppLockAuthResult.SUCCESS;
  if (code === userAuth.UserAuthResultCode.CANCELED || code === userAuth.UserAuthResultCode.TIMEOUT ||
    code === userAuth.UserAuthResultCode.CANCELED_FROM_WIDGET) {
    return AppLockAuthResult.CANCELLED;
  }
  // 「未录入」只有在连锁屏密码都没有时才算不可用；否则按失败处理，不放行
  if (code === userAuth.UserAuthResultCode.NOT_ENROLLED && !appLockAvailable()) return AppLockAuthResult.UNAVAILABLE;
  return AppLockAuthResult.FAILED;
}
