// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'provider_string.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProviderString)
const providerStringProvider = ProviderStringProvider._();

final class ProviderStringProvider
    extends $NotifierProvider<ProviderString, String> {
  const ProviderStringProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'providerStringProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$providerStringHash();

  @$internal
  @override
  ProviderString create() => ProviderString();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$providerStringHash() => r'dd3c65c5da6dd132760491fcea4fd9ac377fa967';

abstract class _$ProviderString extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String, String>,
              String,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
