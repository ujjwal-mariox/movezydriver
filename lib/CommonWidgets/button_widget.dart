import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';


class ButtonWidget extends StatelessWidget {
  final VoidCallback? onTap;
  final String text;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final TextStyle? textStyle;
  final LinearGradient? linearGradient;
  final bool? isEnabled;
  final bool? showBorder;
  final Border? border;

  const ButtonWidget({
        super.key,
        this.onTap,
        required this.text,
        this.height,
        this.borderRadius,
        this.backgroundColor,
        this.textColor,
        this.padding,
        this.margin,
        this.textStyle,
        this.linearGradient,
        this.isEnabled,
        this.showBorder,
        this.border});

  /// A fully transparent fill means this is an outlined button, which must not
  /// cast a shadow. Checked on alpha rather than identity so any 0-alpha colour
  /// counts, not just Colors.transparent.
  static bool _isTransparent(Color? c) => c != null && c.a == 0;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: padding ?? const EdgeInsets.all(0),
        width: MediaQuery.of(context).size.width,
        margin: margin ?? const EdgeInsets.all(0),
        height: height ?? 56,
        decoration: BoxDecoration(
            // Brand orange, not green. This defaulted to AppColors.greenColor,
            // so every primary button that did not pass a colour came out green
            // instead of the design's orange.
            color: backgroundColor ?? AppColors.appColor,
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            border: border,
            // No shadow behind an outlined (transparent) button.
            //
            // This is what made "+ Add Another Vehicle" and the other outlined
            // buttons look faded and dirty: Colors.transparent is 0x00000000,
            // and .withValues(alpha: 0.3) on it yields 30% opaque BLACK — not a
            // transparent shadow. Every transparent-background button was
            // therefore drawn with a grey haze around it.
            boxShadow: _isTransparent(backgroundColor)
                ? null
                : [
                    BoxShadow(
                      color: (backgroundColor ?? AppColors.appColor)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
        ),
        child: Center(
          child: Text(
            text,
            style: textStyle ??
                TextStyle(
                    color: textColor ?? Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}
