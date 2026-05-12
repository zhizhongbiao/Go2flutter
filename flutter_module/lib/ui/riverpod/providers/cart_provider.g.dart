// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(Cart)
const cartProvider = CartProvider._();

final class CartProvider extends $NotifierProvider<Cart, List<Cart>> {
  const CartProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cartProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cartHash();

  @$internal
  @override
  Cart create() => Cart();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Cart> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Cart>>(value),
    );
  }
}

String _$cartHash() => r'7790d7551824300462b1495078819d7fc6825c76';

abstract class _$Cart extends $Notifier<List<Cart>> {
  List<Cart> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<Cart>, List<Cart>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<List<Cart>, List<Cart>>,
              List<Cart>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
