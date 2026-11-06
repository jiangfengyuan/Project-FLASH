// Legacy LAN is temporarily disabled; this module contains no network APIs.
export const LAN_UNAVAILABLE_MESSAGE: string = '局域网传输暂时停用：旧协议存在安全风险。请使用“导出备份”或“系统分享”，通过可信渠道传输 JSON 文件。';
export class LanDevice {
  id: string = '';
  name: string = '';
  host: string = '';
  port: number = 0;
}
