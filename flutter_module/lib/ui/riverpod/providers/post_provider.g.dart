// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'post_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PostProvider)
const postProviderProvider = PostProviderFamily._();

final class PostProviderProvider
    extends $AsyncNotifierProvider<PostProvider, String> {
  const PostProviderProvider._({
    required PostProviderFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'postProviderProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$postProviderHash();

  @override
  String toString() {
    return r'postProviderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  PostProvider create() => PostProvider();

  @override
  bool operator ==(Object other) {
    return other is PostProviderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$postProviderHash() => r'5fade0b00c32589d98689089011168af26408b72';

final class PostProviderFamily extends $Family
    with
        $ClassFamilyOverride<
          PostProvider,
          AsyncValue<String>,
          String,
          FutureOr<String>,
          String
        > {
  const PostProviderFamily._()
    : super(
        retry: null,
        name: r'postProviderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PostProviderProvider call(String params) =>
      PostProviderProvider._(argument: params, from: this);

  @override
  String toString() => r'postProviderProvider';
}

abstract class _$PostProvider extends $AsyncNotifier<String> {
  late final _$args = ref.$arg as String;
  String get params => _$args;

  FutureOr<String> build(String params);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<String>, String>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<String>, String>,
              AsyncValue<String>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
