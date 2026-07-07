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
            color: backgroundColor ?? AppColors.greenColor,
            borderRadius: borderRadius ?? BorderRadius.circular(12),
            border: border,
            boxShadow: [
              BoxShadow(
                color: (backgroundColor ?? AppColors.greenColor).withValues(alpha: 0.3),
                blurRadius: 8,
                offset: Offset(0, 4),
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
