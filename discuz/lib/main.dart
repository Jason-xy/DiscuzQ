import 'dart:async';
import 'package:sentry/sentry.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:discuzq/states/scopedState.dart';
import 'package:discuzq/discuz.dart';
import 'package:discuzq/states/appState.dart';
import 'package:discuzq/utils/appConfigurations.dart';
import 'package:discuzq/widgets/common/appWrapper.dart';
import 'package:discuzq/utils/authHelper.dart';
import 'package:discuzq/widgets/common/discuzIndicater.dart';
import 'package:discuzq/utils/buildInfo.dart';
import 'package:discuzq/widgets/emoji/emojiSync.dart';
import 'package:discuzq/utils/device.dart';
import 'package:discuzq/providers/appConfigProvider.dart';
import 'package:discuzq/providers/userProvider.dart';

///
/// 执行
void main() {
  /// runApp(DiscuzQ());

  /// Run the whole app in a zone to capture all uncaught errors.
  runZoned(
    () => runApp(
      MultiProvider(
        providers: [
          /// APP 配置状态
          ChangeNotifierProvider(create: (_) => AppConfigProvider()),
          ChangeNotifierProvider(create: (_) => UserProvider()),
        ],
        child: DiscuzQ(),
      ),
    ),
    onError: (Object error, StackTrace stackTrace) async {
      if (FlutterDevice.isDevelopment) {
        return;
      }

      /// 初始化buildInfo
      await BuildInfo().init();

      try {
        var sentry = SentryClient(dsn: BuildInfo().info().sentry);
        sentry.captureException(
          exception: error,
          stackTrace: stackTrace,
        );
        debugPrint('Error sent to sentry.io: $error');
      } catch (e) {
        debugPrint('Sending report to sentry.io failed: $e');
        debugPrint('Original error: $error');
      }
    },
  );
}

class DiscuzQ extends StatelessWidget {
  final AppState _appState = AppState();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) => ScopedStateModel<AppState>(
      model: _appState,
      child: Consumer<AppConfigProvider>(builder:
          (BuildContext context, AppConfigProvider conf, Widget child) {
        return ScopedStateModelDescendant<AppState>(
            rebuildOnChange: false,
            builder: (context, child, state) => AppWrapper(
                  onDispose: () {},
                  onInit: () async {
                    /// 初始化buildInfo
                    /// 这个非常重要的！
                    /// 一定要在最开始
                    await BuildInfo().init();

                    await _initApp(context: context,);

                    ///
                    ///
                    /// 异步加载表情数据，不用在乎结果，因为这是个单例，客户端再次调用时，会重新尝试缓存
                    Future.delayed(Duration.zero)
                        .then((_) => EmojiSync().getEmojis());
                  },

                  /// 创建入口APP
                  child: conf.appConf == null
                      ? const _DiscuzAppIndicator()
                      : const Discuz(),
                ));
      }));

  ///
  /// Init app and states
  /// Future builder to makesure appstate init only once
  Future<void> _initApp({BuildContext context}) async {
    await _initAppSettings();

    ///
    /// 如果appconf还没有成功加载则创建初始化页面 并执行APP初始化
    /// 初始化页面会有loading 圈圈
    /// 同步本地配置状态
    await context.read<AppConfigProvider>().update();

    /// 加载本地的用户信息
    await AuthHelper.getUserFromLocal(context: context);
  }

  /// 加载本地的配置
  Future<bool> _initAppSettings() async =>
      await AppConfigurations().initAppSetting();
}

///
/// loading
class _DiscuzAppIndicator extends StatelessWidget {
  const _DiscuzAppIndicator();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        color: Colors.white,
        home: const DiscuzIndicator(
          brightness: Brightness.dark,
        ),
      );
}
