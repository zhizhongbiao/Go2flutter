import 'package:permission_handler/permission_handler.dart';

class PermissionUtil {
  Future<void> requestPermission() async {


    // 1. 获取当前状态
    PermissionStatus status = await Permission.camera.status;

    if (status.isGranted) {
      // 已经授权，直接执行逻辑
      // _openCamera();
    } else if (status.isDenied) {
      // 尚未授权或被拒绝过（但未勾选不再询问）
      // 发起申请
      if (await Permission.camera.request().isGranted) {
        // _openCamera();
      }
    } else if (status.isPermanentlyDenied) {
      // 用户点击了“不再询问”并拒绝
      // 必须引导用户去系统设置页面开启
      openAppSettings();
    }
  }


  Future<void> requestMultiple() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.storage,
      Permission.camera,
    ].request();

    if (statuses[Permission.location]!.isGranted) {
      print("定位权限通过");
    }
  }


}
