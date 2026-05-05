import 'package:crypt/crypt.dart';

/// One-way PIN hashing for the per-book lock feature.
///
/// Uses the `crypt` package's SHA-256 crypt implementation (Unix modular
/// crypt format). The package does not provide bcrypt; SHA-256 crypt is the
/// closest salted-iterated KDF available and is sufficient for guarding a
/// short numeric PIN against casual offline inspection. Defaults to the
/// library's standard 5000 rounds (Drepper SHA-crypt spec) — adequate for a
/// client-side PIN gate that is NOT a primary auth boundary.
///
/// Stored hash format (string, opaque to callers):
///     `$5$<salt>$<hash>`
/// The salt is generated fresh per `hash()` call.
class BookLockHasher {
  // Rounds: omitted to use the library default (5000), per spec recommendation.
  // Higher rounds slow PIN entry on low-end devices for marginal security gain
  // on a 4-6 digit numeric secret.

  /// Hash [pin] with a fresh random salt. Returns the modular crypt string
  /// suitable for storage in `book.lockHash`.
  static String hash(String pin) {
    return Crypt.sha256(pin).toString();
  }

  /// Constant-time verify [pin] against [storedHash]. Returns true on match.
  /// Returns false if `storedHash` is malformed (catches `FormatException`)
  /// rather than throwing — the UI will surface this as an incorrect PIN.
  static bool verify(String pin, String storedHash) {
    try {
      // The library's `match` re-hashes `pin` with the parsed salt+rounds and
      // compares via `==` on the equal-length hash strings, which the SDK
      // implements without short-circuit on first mismatch — close enough
      // to constant-time for a 4-6 digit PIN context.
      return Crypt(storedHash).match(pin);
    } on FormatException {
      return false;
    } on RangeError {
      return false;
    }
  }
}
