

import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'provider_string.g.dart';

@riverpod
class ProviderString extends _$ProviderString{

  @override
  String build()=>"nothing";

  void fuck()=> state="FUck";

  void screw()=> state="Screw";

}