import 'dart:async';

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _liveSteps = 0;
  int _totalStepsToday = 0;
  String _status = 'Đang khởi tạo...';

  Stream<StepCount>? _stepCountStream;
  late Health _health;
  Timer? _healthTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await _initAll();
    },);
  }

  Future<void> _initAll() async {
    await _requestPermissions();

    // Khởi tạo HealthFactory (Google Fit)
    _health = Health();
    await _health.configure();

    // Đọc dữ liệu từ Google Fit mỗi 30 giây
    _healthTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchGoogleFitSteps(),
    );

    // Stream real-time từ cảm biến
    _stepCountStream = Pedometer.stepCountStream;
    _stepCountStream!.listen(_onStepCount).onError(_onStepCountError);

    // Đọc dữ liệu ban đầu
    _fetchGoogleFitSteps();
  }

  Future<void> _requestPermissions() async {
    await Permission.activityRecognition.request();
    await Permission.sensors.request();
  }

  // Lắng nghe stream real-time
  void _onStepCount(StepCount event) {
    setState(() {
      _liveSteps = event.steps;
      _status = "Đang hoạt động...";
    });
  }

  void _onStepCountError(error) {
    setState(() {
      _status = "Lỗi cảm biến: $error";
    });
  }

  // Lấy dữ liệu tổng từ Google Fit
  Future<void> _fetchGoogleFitSteps() async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final types = [HealthDataType.STEPS];
    final yesterday = now.subtract(const Duration(days: 1));
    bool granted = await _health.requestAuthorization(types);
    if (granted) {
      List<HealthDataPoint> data = await _health.getHealthDataFromTypes(
        types: types,
        startTime: yesterday,
        endTime: now,
      );
      int totalSteps = data.fold(0, (sum, point) => sum + (point.value as int));
      setState(() => _totalStepsToday = totalSteps);
    } else {
      setState(() => _status = "Chưa cấp quyền Google Fit");
    }
  }

  @override
  void dispose() {
    _healthTimer?.cancel();
    super.dispose();
  }

  double _calculateCalories() => _totalStepsToday * 0.04;
  double _calculateDistance() => _totalStepsToday * 0.75 / 1000;
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đếm bước chân thông minh',
      theme: ThemeData(primarySwatch: Colors.green),
      home: Scaffold(
        appBar: AppBar(title: const Text("Ứng dụng đếm bước chân")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Trạng thái: $_status",
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                Text(
                  "Bước real-time: $_liveSteps",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Tổng bước hôm nay: $_totalStepsToday",
                  style: const TextStyle(fontSize: 22, color: Colors.blue),
                ),
                const SizedBox(height: 10),
                Text(
                  "Khoảng cách: ${_calculateDistance().toStringAsFixed(2)} km",
                ),
                Text(
                  "Calo tiêu hao: ${_calculateCalories().toStringAsFixed(1)} kcal",
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
