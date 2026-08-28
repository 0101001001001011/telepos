import 'dart:math';

class HoltWinters {
  static List<double> forecast({
    required List<double> data,
    int seasonLength = 7,
    int forecastHorizon = 14,
    double alpha = 0.3,
    double beta = 0.1,
    double gamma = 0.3,
  }) {
    if (data.length < seasonLength * 2) {
      return _simpleMovingAverage(data, forecastHorizon);
    }

    final n = data.length;

    double level = 0;
    for (int i = 0; i < seasonLength; i++) {
      level += data[i];
    }
    level /= seasonLength;

    double trend = 0;
    for (int i = 0; i < seasonLength; i++) {
      trend += (data[seasonLength + i] - data[i]);
    }
    trend /= (seasonLength * seasonLength);

    final seasonal = List<double>.filled(n + forecastHorizon, 0);
    for (int i = 0; i < seasonLength; i++) {
      seasonal[i] = data[i] - level;
    }

    final smoothed = List<double>.filled(n, 0);
    smoothed[0] = level;

    for (int i = 1; i < n; i++) {
      final prevLevel = level;
      final seasonIdx = i % seasonLength;
      final prevSeasonIdx = (i >= seasonLength) ? i - seasonLength : i;

      level =
          alpha * (data[i] - seasonal[prevSeasonIdx]) +
          (1 - alpha) * (prevLevel + trend);

      trend = beta * (level - prevLevel) + (1 - beta) * trend;

      seasonal[i] =
          gamma * (data[i] - level) + (1 - gamma) * seasonal[prevSeasonIdx];

      smoothed[i] = level + trend + seasonal[seasonIdx];
    }

    final result = <double>[];
    for (int i = 1; i <= forecastHorizon; i++) {
      final seasonIdx = (n + i - 1) % seasonLength;
      final forecast =
          level + trend * i + seasonal[n - seasonLength + seasonIdx];
      result.add(max(0, forecast));
    }

    return result;
  }

  static List<double> _simpleMovingAverage(List<double> data, int horizon) {
    if (data.isEmpty) return List.filled(horizon, 0);

    final window = min(7, data.length);
    double sum = 0;
    for (int i = data.length - window; i < data.length; i++) {
      sum += data[i];
    }
    final avg = sum / window;
    return List.filled(horizon, max(0, avg));
  }

  static int detectSeasonLength(List<double> data) {
    if (data.length < 14) return 7;

    final corr7 = _autocorrelation(data, 7);
    final corr30 = data.length >= 60 ? _autocorrelation(data, 30) : 0.0;

    return corr7 > corr30 ? 7 : 30;
  }

  static double _autocorrelation(List<double> data, int lag) {
    if (data.length <= lag) return 0;

    double mean = data.reduce((a, b) => a + b) / data.length;
    double num = 0, den = 0;

    for (int i = 0; i < data.length - lag; i++) {
      num += (data[i] - mean) * (data[i + lag] - mean);
    }
    for (int i = 0; i < data.length; i++) {
      den += (data[i] - mean) * (data[i] - mean);
    }

    return den > 0 ? num / den : 0;
  }
}
