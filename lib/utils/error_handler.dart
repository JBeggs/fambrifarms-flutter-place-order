// Centralized Error Handler
// Provides consistent error processing and user-friendly messages

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../config/app_constants.dart';

class ErrorHandler {
  /// Convert various error types to user-friendly messages
  static String getUserFriendlyMessage(dynamic error) {
    if (error is DioException) {
      return _handleDioError(error);
    }
    
    if (error is ApiException) {
      return _handleApiException(error);
    }
    
    // Handle common Flutter/Dart errors
    final errorString = error.toString().toLowerCase();
    
    if (errorString.contains('network') || 
        errorString.contains('connection') ||
        errorString.contains('timeout')) {
      return AppConstants.networkErrorMessage;
    }
    
    if (errorString.contains('authentication') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden')) {
      return AppConstants.authenticationErrorMessage;
    }
    
    if (errorString.contains('validation') ||
        errorString.contains('invalid')) {
      return AppConstants.validationErrorMessage;
    }
    
    // Default fallback
    return AppConstants.unknownErrorMessage;
  }
  
  static String _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please check your internet connection.';
        
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        switch (statusCode) {
          case 400:
            return _extractErrorFromResponse(error.response) ?? 
                   'Invalid request. Please check your input.';
          case 401:
            return 'Authentication required. Please log in again.';
          case 403:
            return 'Access denied. You don\'t have permission for this action.';
          case 404:
            return 'The requested resource was not found.';
          case 422:
            return _extractValidationErrors(error.response) ??
                   'Validation failed. Please check your input.';
          case 500:
            return 'Server error. Please try again later.';
          case 503:
            return 'Service temporarily unavailable. Please try again later.';
          default:
            return 'Server responded with error ($statusCode).';
        }
        
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
        
      case DioExceptionType.connectionError:
        return AppConstants.networkErrorMessage;
        
      case DioExceptionType.badCertificate:
        return 'Security certificate error. Please check your connection.';
        
      case DioExceptionType.unknown:
        return AppConstants.networkErrorMessage;
    }
  }
  
  static String _handleApiException(ApiException error) {
    // Remove "ApiException: " prefix if present
    String message = error.message;
    if (message.startsWith('ApiException: ')) {
      message = message.substring('ApiException: '.length);
    }
    
    // Check for specific error patterns
    if (message.toLowerCase().contains('network') ||
        message.toLowerCase().contains('connection')) {
      return AppConstants.networkErrorMessage;
    }
    
    if (message.toLowerCase().contains('authentication') ||
        message.toLowerCase().contains('unauthorized')) {
      return AppConstants.authenticationErrorMessage;
    }
    
    return message.isNotEmpty ? message : AppConstants.unknownErrorMessage;
  }
  
  static String? _extractErrorFromResponse(dynamic response) {
    try {
      final data = response?.data;
      if (data is Map<String, dynamic>) {
        // Try common error message fields
        final errorFields = ['message', 'error', 'detail', 'msg'];
        for (final field in errorFields) {
          if (data.containsKey(field) && data[field] is String) {
            return data[field] as String;
          }
        }
        
        // Try to extract from nested error objects
        if (data.containsKey('error') && data['error'] is Map) {
          final errorObj = data['error'] as Map<String, dynamic>;
          for (final field in errorFields) {
            if (errorObj.containsKey(field) && errorObj[field] is String) {
              return errorObj[field] as String;
            }
          }
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }
  
  static String? _extractValidationErrors(dynamic response) {
    try {
      final data = response?.data;
      if (data is Map<String, dynamic>) {
        final errors = <String>[];
        
        // Handle Django REST framework validation errors
        data.forEach((key, value) {
          if (value is List) {
            for (final error in value) {
              if (error is String) {
                errors.add('$key: $error');
              }
            }
          } else if (value is String) {
            errors.add('$key: $value');
          }
        });
        
        if (errors.isNotEmpty) {
          return errors.join('\n');
        }
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return null;
  }
  
  /// Log error for debugging (only in debug mode)
  static void logError(dynamic error, {StackTrace? stackTrace, String? context}) {
    if (kDebugMode) {
      final contextStr = context != null ? '[$context] ' : '';
      debugPrint('${contextStr}Error: $error');
      if (stackTrace != null) {
        debugPrint('Stack trace: $stackTrace');
      }
    }
  }
  
  /// Determine error type for conditional handling
  static ErrorType getErrorType(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return ErrorType.network;
          
        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 401 || statusCode == 403) {
            return ErrorType.authentication;
          }
          if (statusCode == 422 || statusCode == 400) {
            return ErrorType.validation;
          }
          if (statusCode != null && statusCode >= 500) {
            return ErrorType.server;
          }
          return ErrorType.client;
          
        default:
          return ErrorType.unknown;
      }
    }
    
    if (error is ApiException) {
      final message = error.message.toLowerCase();
      if (message.contains('network') || message.contains('connection')) {
        return ErrorType.network;
      }
      if (message.contains('authentication') || message.contains('unauthorized')) {
        return ErrorType.authentication;
      }
      if (message.contains('validation') || message.contains('invalid')) {
        return ErrorType.validation;
      }
    }
    
    return ErrorType.unknown;
  }
  
  /// Check if error is retryable
  static bool isRetryable(dynamic error) {
    final errorType = getErrorType(error);
    return errorType == ErrorType.network || 
           errorType == ErrorType.server ||
           errorType == ErrorType.unknown;
  }
  
  /// Get appropriate retry delay based on error type
  static Duration getRetryDelay(dynamic error, int attemptNumber) {
    final errorType = getErrorType(error);
    
    switch (errorType) {
      case ErrorType.network:
        // Longer delay for network errors
        return AppConstants.getRetryDelay(attemptNumber) * 2;
      case ErrorType.server:
        // Standard exponential backoff for server errors
        return AppConstants.getRetryDelay(attemptNumber);
      default:
        // Shorter delay for other errors
        return AppConstants.retryDelay;
    }
  }
}

enum ErrorType {
  network,
  server,
  client,
  authentication,
  validation,
  unknown,
}

class ApiException implements Exception {
  final String message;
  
  ApiException(this.message);
  
  @override
  String toString() => 'ApiException: $message';
}

