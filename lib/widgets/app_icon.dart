import 'package:flutter/material.dart';
import '../theme/theme_provider.dart';

enum AppIconType {
  chat,
  appearance,
  settings,
  search,
  send,
  attach,
  mic,
  back,
  more,
  edit,
  personAdd,
  pin,
  mute,
  archive,
  delete,
  share,
  copy,
  check,
  doubleCheck,
  lock,
  palette,
  sparkles,
  sound,
  image,
  info,
  close,
  play,
  pause,
}

class AppIcon extends StatelessWidget {
  final dynamic icon;
  final Color? color;
  final double? size;
  final AppThemeData? theme;
  final IconStyleOption? overrideStyle;

  const AppIcon(
    this.icon, {
    super.key,
    this.color,
    this.size,
    this.theme,
    this.overrideStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (icon is IconData) {
      return Icon(
        icon as IconData,
        color: color,
        size: size ?? 20.0,
      );
    }

    final activeStyle = overrideStyle ?? theme?.iconStyle ?? IconStyleOption.rounded;
    final iconData = icon is AppIconType ? _resolveIcon(icon as AppIconType, activeStyle) : Icons.circle;

    return Icon(
      iconData,
      color: color,
      size: size ?? 20.0,
    );
  }

  static IconData resolveForTheme(AppIconType icon, AppThemeData theme) {
    return _resolveIcon(icon, theme.iconStyle);
  }

  static IconData _resolveIcon(AppIconType icon, IconStyleOption style) {
    switch (style) {
      case IconStyleOption.outline:
      case IconStyleOption.minimal:
        return switch (icon) {
          AppIconType.chat => Icons.chat_bubble_outline_rounded,
          AppIconType.appearance => Icons.palette_outlined,
          AppIconType.settings => Icons.settings_outlined,
          AppIconType.search => Icons.search_rounded,
          AppIconType.send => Icons.send_outlined,
          AppIconType.attach => Icons.attach_file_rounded,
          AppIconType.mic => Icons.mic_none_rounded,
          AppIconType.back => Icons.arrow_back_rounded,
          AppIconType.more => Icons.more_vert_rounded,
          AppIconType.edit => Icons.edit_outlined,
          AppIconType.personAdd => Icons.person_add_outlined,
          AppIconType.pin => Icons.push_pin_outlined,
          AppIconType.mute => Icons.volume_off_outlined,
          AppIconType.archive => Icons.archive_outlined,
          AppIconType.delete => Icons.delete_outline_rounded,
          AppIconType.share => Icons.share_outlined,
          AppIconType.copy => Icons.copy_outlined,
          AppIconType.check => Icons.check_rounded,
          AppIconType.doubleCheck => Icons.done_all_rounded,
          AppIconType.lock => Icons.lock_outline_rounded,
          AppIconType.palette => Icons.color_lens_outlined,
          AppIconType.sparkles => Icons.auto_awesome_outlined,
          AppIconType.sound => Icons.volume_up_outlined,
          AppIconType.image => Icons.image_outlined,
          AppIconType.info => Icons.info_outline_rounded,
          AppIconType.close => Icons.close_rounded,
          AppIconType.play => Icons.play_arrow_outlined,
          AppIconType.pause => Icons.pause_outlined,
        };

      case IconStyleOption.filled:
        return switch (icon) {
          AppIconType.chat => Icons.chat_bubble,
          AppIconType.appearance => Icons.palette,
          AppIconType.settings => Icons.settings,
          AppIconType.search => Icons.search,
          AppIconType.send => Icons.send,
          AppIconType.attach => Icons.attach_file,
          AppIconType.mic => Icons.mic,
          AppIconType.back => Icons.arrow_back,
          AppIconType.more => Icons.more_vert,
          AppIconType.edit => Icons.edit,
          AppIconType.personAdd => Icons.person_add,
          AppIconType.pin => Icons.push_pin,
          AppIconType.mute => Icons.volume_off,
          AppIconType.archive => Icons.archive,
          AppIconType.delete => Icons.delete,
          AppIconType.share => Icons.share,
          AppIconType.copy => Icons.copy,
          AppIconType.check => Icons.check,
          AppIconType.doubleCheck => Icons.done_all,
          AppIconType.lock => Icons.lock,
          AppIconType.palette => Icons.color_lens,
          AppIconType.sparkles => Icons.auto_awesome,
          AppIconType.sound => Icons.volume_up,
          AppIconType.image => Icons.image,
          AppIconType.info => Icons.info,
          AppIconType.close => Icons.close,
          AppIconType.play => Icons.play_arrow,
          AppIconType.pause => Icons.pause,
        };

      case IconStyleOption.sharp:
        return switch (icon) {
          AppIconType.chat => Icons.chat_bubble_sharp,
          AppIconType.appearance => Icons.palette_sharp,
          AppIconType.settings => Icons.settings_sharp,
          AppIconType.search => Icons.search_sharp,
          AppIconType.send => Icons.send_sharp,
          AppIconType.attach => Icons.attach_file_sharp,
          AppIconType.mic => Icons.mic_sharp,
          AppIconType.back => Icons.arrow_back_sharp,
          AppIconType.more => Icons.more_vert_sharp,
          AppIconType.edit => Icons.edit_sharp,
          AppIconType.personAdd => Icons.person_add_sharp,
          AppIconType.pin => Icons.push_pin_sharp,
          AppIconType.mute => Icons.volume_off_sharp,
          AppIconType.archive => Icons.archive_sharp,
          AppIconType.delete => Icons.delete_sharp,
          AppIconType.share => Icons.share_sharp,
          AppIconType.copy => Icons.copy_sharp,
          AppIconType.check => Icons.check_sharp,
          AppIconType.doubleCheck => Icons.done_all_sharp,
          AppIconType.lock => Icons.lock_sharp,
          AppIconType.palette => Icons.color_lens_sharp,
          AppIconType.sparkles => Icons.auto_awesome_sharp,
          AppIconType.sound => Icons.volume_up_sharp,
          AppIconType.image => Icons.image_sharp,
          AppIconType.info => Icons.info_sharp,
          AppIconType.close => Icons.close_sharp,
          AppIconType.play => Icons.play_arrow_sharp,
          AppIconType.pause => Icons.pause_sharp,
        };

      case IconStyleOption.rounded:
        return switch (icon) {
          AppIconType.chat => Icons.chat_bubble_rounded,
          AppIconType.appearance => Icons.palette_rounded,
          AppIconType.settings => Icons.settings_rounded,
          AppIconType.search => Icons.search_rounded,
          AppIconType.send => Icons.send_rounded,
          AppIconType.attach => Icons.attach_file_rounded,
          AppIconType.mic => Icons.mic_rounded,
          AppIconType.back => Icons.arrow_back_rounded,
          AppIconType.more => Icons.more_vert_rounded,
          AppIconType.edit => Icons.edit_rounded,
          AppIconType.personAdd => Icons.person_add_rounded,
          AppIconType.pin => Icons.push_pin_rounded,
          AppIconType.mute => Icons.volume_off_rounded,
          AppIconType.archive => Icons.archive_rounded,
          AppIconType.delete => Icons.delete_rounded,
          AppIconType.share => Icons.share_rounded,
          AppIconType.copy => Icons.copy_rounded,
          AppIconType.check => Icons.check_rounded,
          AppIconType.doubleCheck => Icons.done_all_rounded,
          AppIconType.lock => Icons.lock_rounded,
          AppIconType.palette => Icons.color_lens_rounded,
          AppIconType.sparkles => Icons.auto_awesome_rounded,
          AppIconType.sound => Icons.volume_up_rounded,
          AppIconType.image => Icons.image_rounded,
          AppIconType.info => Icons.info_rounded,
          AppIconType.close => Icons.close_rounded,
          AppIconType.play => Icons.play_arrow_rounded,
          AppIconType.pause => Icons.pause_rounded,
        };
    }
  }
}
