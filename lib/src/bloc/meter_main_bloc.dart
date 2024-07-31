import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';

import '../util/environment_util.dart';

final _logger = Logger('MeterMainBloc');

@immutable
class MeterEvent {}

class _InitEvent extends MeterEvent {}

class IgChangeEvent extends MeterEvent {}

class WinkerRightEvent extends MeterEvent {}

class WinkerLeftEvent extends MeterEvent {}

class SpeedUpdated extends MeterEvent {
  SpeedUpdated(this.speed);

  final double speed;
}

class _IlluminationUpdateEvent extends MeterEvent {}

class MeterMainState extends Equatable {
  const MeterMainState(
    this.speedKmh,
    this.igON,
    this.winkerLeftOn,
    this.winkerRightOn,
    this.digitalMeterInformation,
  );

  final double speedKmh;
  final bool igON;
  final bool winkerLeftOn;
  final bool winkerRightOn;
  final List<bool> digitalMeterInformation;

  MeterMainState copyWith({
    double? speedKmh,
    bool? igON,
    bool? winkerLeftOn,
    bool? winkerRightOn,
    List<bool>? digitalMeterInformation,
  }) =>
      MeterMainState(
        speedKmh ?? this.speedKmh,
        igON ?? this.igON,
        winkerLeftOn ?? this.winkerLeftOn,
        winkerRightOn ?? this.winkerRightOn,
        digitalMeterInformation ?? this.digitalMeterInformation,
      );

  @override
  List<Object?> get props => [
        speedKmh,
        igON,
        winkerLeftOn,
        winkerRightOn,
        digitalMeterInformation,
      ];

  @override
  bool? get stringify => false;
}

class MeterMainBloc extends Bloc<MeterEvent, MeterMainState> {

  /// デジタルパネル部の最大長
  static const kDigitalInformationMax = (4 * 7) + 1;

  /// 全消灯パターン
  static const kPatternOff = [false, false, false, false, false, false, false];

  /// オブジェクト初期値
  static const kStateInit = MeterMainState(0.0, false, false, false, [
    ...kPatternOff, // 100の桁
    ...kPatternOff, // 10の桁
    ...kPatternOff, // 1の桁
    false, // ドット
    ...kPatternOff // 小数点1桁
  ]);

  /// 全パネル点灯／消灯
  List<bool> fillInformation({required bool input}) {
    List<bool> result = [];

    for (int i = 0; i < kDigitalInformationMax; i++) {
      result.add(input);
    }

    return result;
  }

  MeterMainBloc({MeterMainState? init}) : super(init ?? kStateInit) {
    on<_InitEvent>((event, emit) {
      _logger.info('init completed.');
    });

    on<WinkerLeftEvent>((event, emit) =>
        emit(state.copyWith(winkerLeftOn: !state.winkerLeftOn)));

    on<WinkerRightEvent>((event, emit) =>
        emit(state.copyWith(winkerRightOn: !state.winkerRightOn)));

    on<IgChangeEvent>((event, emit) {
      final igonNewStatus = !state.igON;
      emit(state.copyWith(
        igON: igonNewStatus,
        digitalMeterInformation: fillInformation(input: false),
      ));

      // coverage:ignore-start
      // この処理は正規の作り込みでないので、テストは不要
      // IGON中はデジタルメーターの各パネルを点灯させる
      if (!isUnitTestMode()) {
        if (igonNewStatus) {
          timer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
            add(_IlluminationUpdateEvent());
          });
        } else {
          timer?.cancel();
          count = 0;
        }
      }
      // coverage:ignore-end
    });

// coverage:ignore-start
// デバッグ点灯モードの処理は正規の作り込みでないので、テストは不要
    on<_IlluminationUpdateEvent>((event, emit) {
      List<bool> newInfo = <bool>[...state.digitalMeterInformation];

      if (count > kDigitalInformationMax - 1) {
        count = 0;
        newInfo = fillInformation(input: false);
      }
      newInfo[count] = true;
      if (count > 0) {
        newInfo[count - 1] = false;
      }
      count++;

      emit(state.copyWith(
        digitalMeterInformation: newInfo,
      ));
      // _logger.info('_InnerTestCounted newInfo=${_logger.dump(newInfo)}');
    });
// coverage:ignore-end

    add(_InitEvent());
  }

// coverage:ignore-start
  Timer? timer;
  int count = 0;
// coverage:ignore-end
}
