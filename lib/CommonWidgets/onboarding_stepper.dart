import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:movezy_driver_app/Utils/AppColors/app_colors.dart';

/// A dynamic 3-step onboarding stepper widget with progress bar.
///
/// [currentStep] is 0-indexed: 0 = Owner Details, 1 = Vehicle Details, 2 = Driver Details.
class OnboardingStepper extends StatelessWidget {
  final int currentStep;

  const OnboardingStepper({super.key, required this.currentStep});

  static List<String> get _labels => [
    'owner_details'.tr,
    'vehicle_details'.tr,
    'driver_details'.tr,
  ];

  // Progress percentage per step
  int get _progressPercent {
    switch (currentStep) {
      case 0: return 30;
      case 1: return 60;
      case 2: return 80;
      default: return 100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column(
        children: [
          // Top banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.appColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.rocket_launch, color: AppColors.appColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  'complete_onboarding'.tr,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.appColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Progress bar with percentage
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progressPercent / 100,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(AppColors.appColor),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_progressPercent%',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.appColor),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Step indicators
          Row(
            children: List.generate(_labels.length * 2 - 1, (index) {
              if (index.isOdd) {
                final stepBefore = index ~/ 2;
                final isCompleted = stepBefore < currentStep;
                return Expanded(
                  child: Container(
                    height: 2,
                    color: isCompleted ? AppColors.appColor : Colors.grey.shade300,
                  ),
                );
              }
              final stepIndex = index ~/ 2;
              return _buildStep(stepIndex);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep(int stepIndex) {
    final bool isCompleted = stepIndex < currentStep;
    final bool isActive = stepIndex == currentStep;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted
                ? AppColors.appColor
                : isActive
                    ? Colors.white
                    : Colors.grey.shade300,
            border: isActive
                ? Border.all(color: AppColors.appColor, width: 2.5)
                : null,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : isActive
                    ? Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.appColor,
                        ),
                      )
                    : Icon(Icons.lock, color: Colors.grey.shade600, size: 16),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _labels[stepIndex],
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive || isCompleted ? FontWeight.w600 : FontWeight.w400,
            color: isCompleted
                ? AppColors.appColor
                : isActive
                    ? Colors.black
                    : Colors.grey.shade500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
