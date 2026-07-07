import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';
import 'package:flutter/material.dart';

class SliderButtonWidget extends StatelessWidget {
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
  final Color? arrowColor;


  const SliderButtonWidget({
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
    this.border,
    this.arrowColor
  });

  @override
  Widget build(BuildContext context) {

    const Color cardBorder = Color(0xFFE6EEF2);

    return InkWell(
      onTap: onTap ?? () {},
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Container(
        padding: padding ?? const EdgeInsets.all(0),
        width: MediaQuery.of(context).size.width,
        margin: margin ?? const EdgeInsets.all(0),
        height: height ?? 50,
        decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.greenColor,
            borderRadius: borderRadius ?? BorderRadius.circular(20),
            border: border
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              margin: EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(color: cardBorder),
              ),
              child: Center(
                child: Icon(Icons.keyboard_double_arrow_right, color: arrowColor, size: 30,),
              ),
            ),

            Spacer(),

            Text(
              text,
              style: textStyle ??
                  TextStyle(
                      color: textColor ?? Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
            ),

            Spacer(),

            SizedBox(width: 58,)
          ],
        ),
      ),
    );
  }
}
