/// Custom exceptions for Starknet wallet operations

/// Base exception for all Starknet wallet errors
class StarknetException implements Exception {
  StarknetException(this.message, {this.details});

  final String message;
  final String? details;

  @override
  String toString() {
    if (details != null) {
      return 'StarknetException: $message\nDetails: $details';
    }
    return 'StarknetException: $message';
  }
}

/// Exception thrown when wallet initialization fails
class StarknetWalletInitializationException extends StarknetException {
  StarknetWalletInitializationException(String message, {String? details})
      : super(message, details: details);

  @override
  String toString() => 'StarknetWalletInitializationException: $message${details != null ? '\nDetails: $details' : ''}';
}

/// Exception thrown when key derivation fails
class StarknetKeyDerivationException extends StarknetException {
  StarknetKeyDerivationException(String message, {String? details})
      : super(message, details: details);

  @override
  String toString() => 'StarknetKeyDerivationException: $message${details != null ? '\nDetails: $details' : ''}';
}

/// Exception thrown when account deployment fails
class StarknetDeploymentException extends StarknetException {
  StarknetDeploymentException(String message, {String? details})
      : super(message, details: details);

  @override
  String toString() => 'StarknetDeploymentException: $message${details != null ? '\nDetails: $details' : ''}';
}

/// Exception thrown when transaction creation or submission fails
class StarknetTransactionException extends StarknetException {
  StarknetTransactionException(String message, {String? details})
      : super(message, details: details);

  @override
  String toString() => 'StarknetTransactionException: $message${details != null ? '\nDetails: $details' : ''}';
}

/// Exception thrown when balance is insufficient
class StarknetInsufficientBalanceException extends StarknetException {
  StarknetInsufficientBalanceException({
    required BigInt required,
    required BigInt available,
    String? operation,
  }) : super(
          'Insufficient balance${operation != null ? ' for $operation' : ''}',
          details: 'Required: $required wei\nAvailable: $available wei\nShortfall: ${required - available} wei',
        );

  @override
  String toString() => 'StarknetInsufficientBalanceException: $message${details != null ? '\n$details' : ''}';
}

/// Exception thrown when network operations fail
class StarknetNetworkException extends StarknetException {
  StarknetNetworkException(String message, {String? details})
      : super(message, details: details);

  @override
  String toString() => 'StarknetNetworkException: $message${details != null ? '\nDetails: $details' : ''}';
}

/// Exception thrown when address validation fails
class StarknetInvalidAddressException extends StarknetException {
  StarknetInvalidAddressException(String address, {String? reason})
      : super(
          'Invalid Starknet address: $address',
          details: reason,
        );

  @override
  String toString() => 'StarknetInvalidAddressException: $message${details != null ? '\nReason: $details' : ''}';
}

/// Exception thrown when RPC node is unreachable or unhealthy
class StarknetNodeException extends StarknetException {
  StarknetNodeException(String message, {String? details})
      : super(message, details: details);

  @override
  String toString() => 'StarknetNodeException: $message${details != null ? '\nDetails: $details' : ''}';
}
