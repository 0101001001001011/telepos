import 'dart:async';

import 'package:talker/talker.dart';

enum JobPriority { low, normal, high, critical }

enum JobStatus { pending, running, completed, failed, cancelled }

class JobResult {
  final bool success;
  final String? error;
  final Duration duration;
  final DateTime completedAt;

  JobResult({
    required this.success,
    this.error,
    required this.duration,
    required this.completedAt,
  });

  factory JobResult.success(Duration duration) =>
      JobResult(success: true, duration: duration, completedAt: DateTime.now());

  factory JobResult.failure(String error, Duration duration) => JobResult(
    success: false,
    error: error,
    duration: duration,
    completedAt: DateTime.now(),
  );
}

abstract class BackgroundJob {
  String get id;

  String get name;

  JobPriority get priority => JobPriority.normal;

  Duration? get interval;

  Duration get timeout => const Duration(minutes: 5);

  int get maxRetries => 3;

  Duration get retryDelay => const Duration(seconds: 30);

  Future<void> execute();

  bool canRunNow() => true;
}

class RegisteredJob {
  final BackgroundJob job;
  JobStatus status;
  DateTime? lastRun;
  DateTime? nextRun;
  int failureCount;
  JobResult? lastResult;
  Timer? _timer;

  RegisteredJob({
    required this.job,
    this.status = JobStatus.pending,
    this.lastRun,
    this.nextRun,
    this.failureCount = 0,
    this.lastResult,
  });

  void scheduleNext() {
    if (job.interval != null) {
      nextRun = DateTime.now().add(job.interval!);
    }
  }
}

class JobScheduler {
  final Talker _logger;
  final Map<String, RegisteredJob> _jobs = {};
  final _runningJobs = <String>{};

  bool _isRunning = false;
  Timer? _schedulerTimer;

  final _jobCompletedController =
      StreamController<(String, JobResult)>.broadcast();

  JobScheduler({Talker? logger}) : _logger = logger ?? Talker();

  Stream<(String, JobResult)> get onJobCompleted =>
      _jobCompletedController.stream;

  bool get isRunning => _isRunning;

  List<RegisteredJob> get jobs => _jobs.values.toList();

  void start() {
    if (_isRunning) return;

    _isRunning = true;
    _logger.info('JobScheduler started');

    _schedulerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkAndRunJobs();
    });

    for (final registered in _jobs.values) {
      if (registered.job.interval != null) {
        registered.scheduleNext();
      }
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    _schedulerTimer?.cancel();
    _schedulerTimer = null;

    for (final registered in _jobs.values) {
      registered._timer?.cancel();
      registered._timer = null;
    }

    _logger.info('JobScheduler stopped');
  }

  void register(BackgroundJob job) {
    if (_jobs.containsKey(job.id)) {
      _logger.warning('Job ${job.id} already registered, replacing');
      unregister(job.id);
    }

    final registered = RegisteredJob(job: job);
    _jobs[job.id] = registered;

    if (_isRunning && job.interval != null) {
      registered.scheduleNext();
    }

    _logger.debug('Registered job: ${job.name} (${job.id})');
  }

  void unregister(String jobId) {
    final registered = _jobs.remove(jobId);
    if (registered != null) {
      registered._timer?.cancel();
      _logger.debug('Unregistered job: ${registered.job.name}');
    }
  }

  Future<JobResult> runNow(String jobId) async {
    final registered = _jobs[jobId];
    if (registered == null) {
      throw StateError('Job $jobId not found');
    }

    return _executeJob(registered);
  }

  void cancel(String jobId) {
    if (_runningJobs.contains(jobId)) {
      final registered = _jobs[jobId];
      if (registered != null) {
        registered.status = JobStatus.cancelled;
        _runningJobs.remove(jobId);
        _logger.info('Cancelled job: ${registered.job.name}');
      }
    }
  }

  RegisteredJob? getJob(String jobId) => _jobs[jobId];

  void _checkAndRunJobs() {
    if (!_isRunning) return;

    final now = DateTime.now();

    final sortedJobs = _jobs.values.toList()
      ..sort((a, b) => b.job.priority.index.compareTo(a.job.priority.index));

    for (final registered in sortedJobs) {
      if (_runningJobs.contains(registered.job.id)) continue;

      if (registered.nextRun != null && registered.nextRun!.isAfter(now))
        continue;

      if (!registered.job.canRunNow()) continue;

      _executeJob(registered);
    }
  }

  Future<JobResult> _executeJob(RegisteredJob registered) async {
    final job = registered.job;
    final jobId = job.id;

    _runningJobs.add(jobId);
    registered.status = JobStatus.running;
    registered.lastRun = DateTime.now();

    _logger.debug('Starting job: ${job.name}');

    final stopwatch = Stopwatch()..start();
    late JobResult result;

    try {
      await job.execute().timeout(job.timeout);

      stopwatch.stop();
      result = JobResult.success(stopwatch.elapsed);

      registered.status = JobStatus.completed;
      registered.failureCount = 0;

      _logger.info(
        'Job completed: ${job.name} in ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, st) {
      stopwatch.stop();
      result = JobResult.failure(e.toString(), stopwatch.elapsed);

      registered.status = JobStatus.failed;
      registered.failureCount++;

      _logger.error('Job failed: ${job.name} - $e', e, st);

      if (registered.failureCount < job.maxRetries) {
        registered.nextRun = DateTime.now().add(job.retryDelay);
        _logger.info(
          'Scheduling retry for ${job.name} in ${job.retryDelay.inSeconds}s '
          '(attempt ${registered.failureCount + 1}/${job.maxRetries})',
        );
      }
    } finally {
      _runningJobs.remove(jobId);
      registered.lastResult = result;

      if (job.interval != null && registered.failureCount < job.maxRetries) {
        registered.scheduleNext();
      }
    }

    _jobCompletedController.add((jobId, result));
    return result;
  }

  Future<void> dispose() async {
    await stop();
    await _jobCompletedController.close();
  }
}
