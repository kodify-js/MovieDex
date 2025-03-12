import 'package:flutter/material.dart';
import 'package:appwrite/appwrite.dart';
import 'package:moviedex/services/connectivity_service.dart';
import 'dart:io';

class ErrorHandlers {
  static void showErrorSnackbar(BuildContext context, dynamic error) {
    String message = _getErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.red.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  static void showSuccessSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Enhanced error message formatter with network error detection
  static String _getErrorMessage(dynamic error) {
    if (error is AppwriteException) {
      return error.message ?? 'An error occurred';
    } else if (error is String) {
      // Check for common error patterns and provide friendly messages
      if (error.contains('SocketException') ||
          error.contains('Connection refused') ||
          error.contains('Network is unreachable')) {
        return 'Unable to connect to the server. Check your internet connection.';
      } else if (error.contains('api_key')) {
        return 'There was a problem with the app configuration.';
      } else if (error.contains('timeout')) {
        return 'The connection timed out. Please try again.';
      }
      return error;
    } else if (error is Exception) {
      if (error is SocketException || error is HttpException) {
        return 'Network connection issue. Please check your internet.';
      } else if (error.toString().contains('timeout')) {
        return 'The connection timed out. Please try again later.';
      }
      return error.toString().replaceFirst('Exception: ', '');
    } else {
      return 'Something went wrong. Please try again.';
    }
  }

  // Check if the error is related to network connectivity
  static bool isNetworkError(dynamic error) {
    if (error is SocketException || error is HttpException) {
      return true;
    }

    if (error is String) {
      return error.contains('SocketException') ||
          error.contains('Connection refused') ||
          error.contains('Network is unreachable') ||
          error.contains('timeout');
    }

    String errorString = error.toString().toLowerCase();
    return errorString.contains('socket') ||
        errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('internet') ||
        errorString.contains('timeout');
  }
}
