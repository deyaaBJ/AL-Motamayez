import 'package:flutter/material.dart';
import 'package:motion_toast/motion_toast.dart';

enum ToastType { success, error, warning }

void showAppToast(BuildContext context, String message, ToastType type) {
  switch (type) {
    case ToastType.success:
      MotionToast.success(
        description: Text(message),
        animationType: AnimationType.slideInFromTop,
        toastAlignment: Alignment.topCenter,
      ).show(context);
      break;

    case ToastType.error:
      MotionToast.error(
        description: Text(message),
        animationType: AnimationType.slideInFromTop,
        toastAlignment: Alignment.topCenter,
      ).show(context);
      break;

    case ToastType.warning:
      MotionToast.warning(
        description: Text(message),
        animationType: AnimationType.slideInFromTop,
        toastAlignment: Alignment.topCenter,
      ).show(context);
      break;
  }
}
