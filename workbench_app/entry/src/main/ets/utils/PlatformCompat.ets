import { deviceInfo } from '@kit.BasicServicesKit';

/** 最低支持 API 20；按接口引入版本选择实现，不能用编译版本判断设备能力。 */
export class PlatformCompat {
  static get desktopWindow(): boolean {
    return deviceInfo.deviceType === '2in1';
  }

  static supports(apiVersion: number): boolean {
    return deviceInfo.sdkApiVersion >= apiVersion;
  }

  static get immersiveMaterial(): boolean {
    return PlatformCompat.supports(26);
  }

  static get floatingTabs(): boolean {
    return PlatformCompat.supports(23);
  }
}
