class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    this.emailVerified = true,
    this.googleLinked = true,
    this.hasPassword = false,
    this.pendingEmail,
    this.defaultCurrency = 'PHP',
  });

  final String id;
  final String name;
  final String email;
  final bool emailVerified;
  final bool googleLinked;
  final bool hasPassword;
  final String? pendingEmail;
  final String defaultCurrency;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, parts.first.length.clamp(1, 2)).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  AppUser copyWith({
    String? name,
    String? email,
    bool? emailVerified,
    bool? googleLinked,
    bool? hasPassword,
    String? pendingEmail,
    bool clearPendingEmail = false,
    String? defaultCurrency,
  }) =>
      AppUser(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        emailVerified: emailVerified ?? this.emailVerified,
        googleLinked: googleLinked ?? this.googleLinked,
        hasPassword: hasPassword ?? this.hasPassword,
        pendingEmail: clearPendingEmail ? null : (pendingEmail ?? this.pendingEmail),
        defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      );
}
