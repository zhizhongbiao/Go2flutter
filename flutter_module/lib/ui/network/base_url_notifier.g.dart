// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_url_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BaseUrlNotifier)
const baseUrlProvider = BaseUrlNotifierProvider._();

final class BaseUrlNotifierProvider
    extends $NotifierProvider<BaseUrlNotifier, String> {
  const BaseUrlNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'baseUrlProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$baseUrlNotifierHash();

  @$internal
  @override
  BaseUrlNotifier create() => BaseUrlNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$baseUrlNotifierHash() => r'bd01813f02a6b32705543b1a0b4c9799b3252d00';

abstract class _$BaseUrlNotifier extends $Notifier<String> {
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
