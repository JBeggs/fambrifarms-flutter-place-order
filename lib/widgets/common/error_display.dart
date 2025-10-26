// Standardized Error Display Widget
// Provides consistent error UI patterns across the application

import 'package:flutter/material.dart';
import '../../config/app_constants.dart';

class ErrorDisplay extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData? icon;
  final bool showRetryButton;
  final String? retryButtonText;
  final EdgeInsets? padding;

  const ErrorDisplay({
    super.key,
    required this.message,
    this.onRetry,
    this.icon,
    this.showRetryButton = true,
    this.retryButtonText,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(AppConstants.spacingLarge),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: AppConstants.spacingMedium),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (showRetryButton && onRetry != null) ...[
              const SizedBox(height: AppConstants.spacingLarge),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(retryButtonText ?? 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final IconData? icon;
  final Color? backgroundColor;

  const ErrorCard({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
    this.icon,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: backgroundColor ?? Theme.of(context).colorScheme.errorContainer,
      elevation: AppConstants.cardElevation,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMedium),
        child: Row(
          children: [
            Icon(
              icon ?? Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
              size: AppConstants.iconSize,
            ),
            const SizedBox(width: AppConstants.spacingMedium),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(width: AppConstants.spacingSmall),
              IconButton(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                tooltip: 'Retry',
              ),
            ],
            if (onDismiss != null) ...[
              const SizedBox(width: AppConstants.spacingSmall),
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close),
                tooltip: 'Dismiss',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;
  final bool isVisible;

  const ErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spacingMedium),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: AppConstants.iconSize,
          ),
          const SizedBox(width: AppConstants.spacingMedium),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          if (onDismiss != null)
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close),
              tooltip: 'Dismiss',
            ),
        ],
      ),
    );
  }
}

class NetworkErrorDisplay extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? customMessage;

  const NetworkErrorDisplay({
    super.key,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      message: customMessage ?? AppConstants.networkErrorMessage,
      onRetry: onRetry,
      icon: Icons.wifi_off,
      retryButtonText: 'Check Connection',
    );
  }
}

class ServerErrorDisplay extends StatelessWidget {
  final VoidCallback? onRetry;
  final String? customMessage;

  const ServerErrorDisplay({
    super.key,
    this.onRetry,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      message: customMessage ?? AppConstants.serverErrorMessage,
      onRetry: onRetry,
      icon: Icons.cloud_off,
      retryButtonText: 'Try Again',
    );
  }
}

class AuthenticationErrorDisplay extends StatelessWidget {
  final VoidCallback? onLogin;
  final String? customMessage;

  const AuthenticationErrorDisplay({
    super.key,
    this.onLogin,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDisplay(
      message: customMessage ?? AppConstants.authenticationErrorMessage,
      onRetry: onLogin,
      icon: Icons.lock_outline,
      retryButtonText: 'Log In',
    );
  }
}

